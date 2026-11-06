import { Router, Request, Response } from 'express';
import { db, SleepSession, User } from '../models/database';
import { sleepAnalysisService } from '../services/sleepAnalysis';
import { circadianRhythmService } from '../services/circadianRhythm';
import { notificationService } from '../services/notifications';

const router = Router();

/**
 * Health check endpoint
 */
router.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

/**
 * Register or update user
 * POST /api/users
 */
router.post('/users', (req: Request, res: Response) => {
  try {
    const { id, device_token, timezone, wake_time, sleep_time, pre_dip_notification_minutes, notifications_enabled } = req.body;

    if (!id) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    const existingUser = db.prepare('SELECT * FROM users WHERE id = ?').get(id) as User | undefined;

    if (existingUser) {
      const stmt = db.prepare(`
        UPDATE users 
        SET device_token = COALESCE(?, device_token),
            timezone = COALESCE(?, timezone),
            wake_time = COALESCE(?, wake_time),
            sleep_time = COALESCE(?, sleep_time),
            pre_dip_notification_minutes = COALESCE(?, pre_dip_notification_minutes),
            notifications_enabled = COALESCE(?, notifications_enabled),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `);
      stmt.run(device_token, timezone, wake_time, sleep_time, pre_dip_notification_minutes, notifications_enabled, id);
    } else {
      const stmt = db.prepare(`
        INSERT INTO users (id, device_token, timezone, wake_time, sleep_time, pre_dip_notification_minutes, notifications_enabled)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `);
      stmt.run(
        id,
        device_token || null,
        timezone || 'UTC',
        wake_time || null,
        sleep_time || null,
        pre_dip_notification_minutes || 30,
        notifications_enabled !== undefined ? notifications_enabled : 1
      );
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
    res.json({ success: true, user });
  } catch (error) {
    console.error('Error creating/updating user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get user by ID
 * GET /api/users/:id
 */
router.get('/users/:id', (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(user);
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Submit sleep session
 * POST /api/sleep
 */
router.post('/sleep', (req: Request, res: Response) => {
  try {
    const session: SleepSession = req.body;

    if (!session.user_id || !session.start_time || !session.end_time) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const stmt = db.prepare(`
      INSERT INTO sleep_sessions 
      (user_id, start_time, end_time, duration_minutes, quality_score, 
       deep_sleep_minutes, rem_sleep_minutes, light_sleep_minutes, awake_minutes, source)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    const result = stmt.run(
      session.user_id,
      session.start_time,
      session.end_time,
      session.duration_minutes,
      session.quality_score || null,
      session.deep_sleep_minutes || null,
      session.rem_sleep_minutes || null,
      session.light_sleep_minutes || null,
      session.awake_minutes || null,
      session.source
    );

    const previousSessions = db.prepare(`
      SELECT * FROM sleep_sessions 
      WHERE user_id = ? AND id != ?
      ORDER BY start_time DESC 
      LIMIT 7
    `).all(session.user_id, result.lastInsertRowid) as SleepSession[];

    const analysis = sleepAnalysisService.analyzeSleep(session, previousSessions);
    const sleepDebt = sleepAnalysisService.calculateSleepDebt([session, ...previousSessions]);

    const prediction = circadianRhythmService.predictDayEnergy(session, sleepDebt);

    const today = new Date(session.end_time).toISOString().split('T')[0];
    const predStmt = db.prepare(`
      INSERT INTO energy_predictions 
      (user_id, date, wake_time, dip_time, sleep_debt_minutes, circadian_phase, alertness_curve)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(user_id, date) DO UPDATE SET
        wake_time = excluded.wake_time,
        dip_time = excluded.dip_time,
        sleep_debt_minutes = excluded.sleep_debt_minutes,
        circadian_phase = excluded.circadian_phase,
        alertness_curve = excluded.alertness_curve
    `);

    predStmt.run(
      session.user_id,
      today,
      prediction.wake_time,
      prediction.dip_time,
      sleepDebt,
      0,
      JSON.stringify(prediction.alertness_curve)
    );

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(session.user_id) as User | undefined;
    if (user?.device_token && user.notifications_enabled) {
      notificationService.scheduleWakeUpNotification(
        session.user_id,
        user.device_token,
        new Date(prediction.wake_time),
        analysis.score.overall
      );

      notificationService.schedulePreDipNotification(
        session.user_id,
        user.device_token,
        new Date(prediction.dip_time),
        user.pre_dip_notification_minutes
      );
    }

    res.json({
      success: true,
      session_id: result.lastInsertRowid,
      analysis,
      prediction,
    });
  } catch (error) {
    console.error('Error submitting sleep session:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get sleep history
 * GET /api/sleep/:userId?days=7
 */
router.get('/sleep/:userId', (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const days = parseInt(req.query.days as string) || 7;

    const sessions = db.prepare(`
      SELECT * FROM sleep_sessions 
      WHERE user_id = ? 
      ORDER BY start_time DESC 
      LIMIT ?
    `).all(userId, days) as SleepSession[];

    res.json({ sessions });
  } catch (error) {
    console.error('Error fetching sleep history:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get today's energy prediction
 * GET /api/energy/:userId
 */
router.get('/energy/:userId', (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const date = req.query.date as string || new Date().toISOString().split('T')[0];

    const prediction = db.prepare(`
      SELECT * FROM energy_predictions 
      WHERE user_id = ? AND date = ?
    `).get(userId, date) as any;

    if (!prediction) {
      return res.status(404).json({ error: 'No prediction found for this date' });
    }

    prediction.alertness_curve = JSON.parse(prediction.alertness_curve);

    const currentTime = new Date();
    const dipTime = new Date(prediction.dip_time);
    const hoursUntilDip = circadianRhythmService.calculateHoursUntilDip(dipTime, currentTime);

    res.json({
      ...prediction,
      hours_until_dip: hoursUntilDip,
    });
  } catch (error) {
    console.error('Error fetching energy prediction:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Log journey/commute time
 * POST /api/journey
 */
router.post('/journey', (req: Request, res: Response) => {
  try {
    const { user_id, date, duration_minutes, start_time, end_time } = req.body;

    if (!user_id || !date || !duration_minutes || !start_time || !end_time) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const stmt = db.prepare(`
      INSERT INTO journey_logs (user_id, date, duration_minutes, start_time, end_time)
      VALUES (?, ?, ?, ?, ?)
    `);

    const result = stmt.run(user_id, date, duration_minutes, start_time, end_time);

    res.json({ success: true, journey_id: result.lastInsertRowid });
  } catch (error) {
    console.error('Error logging journey:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get journey history
 * GET /api/journey/:userId?days=7
 */
router.get('/journey/:userId', (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const days = parseInt(req.query.days as string) || 7;

    const journeys = db.prepare(`
      SELECT * FROM journey_logs 
      WHERE user_id = ? 
      ORDER BY date DESC 
      LIMIT ?
    `).all(userId, days);

    res.json({ journeys });
  } catch (error) {
    console.error('Error fetching journey history:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get dashboard data (all info for today)
 * GET /api/dashboard/:userId
 */
router.get('/dashboard/:userId', (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const today = new Date().toISOString().split('T')[0];

    const lastSleep = db.prepare(`
      SELECT * FROM sleep_sessions 
      WHERE user_id = ? 
      ORDER BY end_time DESC 
      LIMIT 1
    `).get(userId) as SleepSession | undefined;

    const recentSleep = db.prepare(`
      SELECT * FROM sleep_sessions 
      WHERE user_id = ? 
      ORDER BY start_time DESC 
      LIMIT 7
    `).all(userId) as SleepSession[];

    const energyPrediction = db.prepare(`
      SELECT * FROM energy_predictions 
      WHERE user_id = ? AND date = ?
    `).get(userId, today) as any;

    if (energyPrediction) {
      energyPrediction.alertness_curve = JSON.parse(energyPrediction.alertness_curve);
    }

    const todayJourney = db.prepare(`
      SELECT * FROM journey_logs 
      WHERE user_id = ? AND date = ?
    `).get(userId, today);

    res.json({
      last_sleep: lastSleep,
      recent_sleep: recentSleep,
      energy_prediction: energyPrediction,
      today_journey: todayJourney,
    });
  } catch (error) {
    console.error('Error fetching dashboard:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
