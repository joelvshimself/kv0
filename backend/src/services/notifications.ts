import apn from 'apn';
import admin from 'firebase-admin';
import { db, User, NotificationLog } from '../models/database';
import cron from 'node-cron';

/**
 * Notification Service
 * 
 * Handles scheduling and sending notifications via:
 * - APNs (Apple Push Notification service) for iOS
 * - FCM (Firebase Cloud Messaging) for Android
 * 
 * Two types of notifications:
 * 1. Wake-up notification: Sent in the morning with sleep score
 * 2. Pre-dip notification: Sent N minutes before predicted energy dip
 */

export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, any>;
}

export class NotificationService {
  private apnProvider?: apn.Provider;
  private fcmInitialized = false;

  constructor() {
    this.initializeAPNs();
    this.initializeFCM();
  }

  private initializeAPNs() {
    try {
      const keyId = process.env.APNS_KEY_ID;
      const teamId = process.env.APNS_TEAM_ID;
      const keyPath = process.env.APNS_KEY_PATH;

      if (!keyId || !teamId || !keyPath) {
        console.log('APNs credentials not configured. iOS push notifications will be disabled.');
        return;
      }

      this.apnProvider = new apn.Provider({
        token: {
          key: keyPath,
          keyId: keyId,
          teamId: teamId,
        },
        production: process.env.APNS_PRODUCTION === 'true',
      });

      console.log('APNs initialized successfully');
    } catch (error) {
      console.error('Failed to initialize APNs:', error);
    }
  }

  private initializeFCM() {
    try {
      const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

      if (!serviceAccountPath) {
        console.log('FCM credentials not configured. Android push notifications will be disabled.');
        return;
      }

      admin.initializeApp({
        credential: admin.credential.cert(serviceAccountPath),
      });

      this.fcmInitialized = true;
      console.log('FCM initialized successfully');
    } catch (error) {
      console.error('Failed to initialize FCM:', error);
    }
  }

  /**
   * Send notification via APNs (iOS)
   */
  private async sendAPNs(deviceToken: string, payload: NotificationPayload): Promise<void> {
    if (!this.apnProvider) {
      throw new Error('APNs not configured');
    }

    const notification = new apn.Notification();
    notification.alert = {
      title: payload.title,
      body: payload.body,
    };
    notification.sound = 'default';
    notification.badge = 1;
    notification.topic = process.env.APNS_BUNDLE_ID || 'com.kv0.app';
    
    if (payload.data) {
      notification.payload = payload.data;
    }

    const result = await this.apnProvider.send(notification, deviceToken);
    
    if (result.failed.length > 0) {
      throw new Error(`APNs failed: ${result.failed[0].response?.reason}`);
    }
  }

  /**
   * Send notification via FCM (Android)
   */
  private async sendFCM(deviceToken: string, payload: NotificationPayload): Promise<void> {
    if (!this.fcmInitialized) {
      throw new Error('FCM not configured');
    }

    const message = {
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
      token: deviceToken,
    };

    await admin.messaging().send(message);
  }

  /**
   * Send notification to user (auto-detects platform from device token format)
   */
  async sendNotification(
    userId: string,
    deviceToken: string,
    payload: NotificationPayload,
    notificationType: string
  ): Promise<void> {
    const scheduledTime = new Date().toISOString();
    const logStmt = db.prepare(`
      INSERT INTO notifications_log (user_id, notification_type, scheduled_time, status)
      VALUES (?, ?, ?, 'sending')
    `);
    const result = logStmt.run(userId, notificationType, scheduledTime);
    const logId = result.lastInsertRowid;

    try {
      if (deviceToken.length === 64) {
        await this.sendAPNs(deviceToken, payload);
      } else {
        await this.sendFCM(deviceToken, payload);
      }

      db.prepare(`
        UPDATE notifications_log 
        SET status = 'sent', sent_time = ? 
        WHERE id = ?
      `).run(new Date().toISOString(), logId);
    } catch (error) {
      db.prepare(`
        UPDATE notifications_log 
        SET status = 'failed', error = ? 
        WHERE id = ?
      `).run(String(error), logId);
      throw error;
    }
  }

  /**
   * Schedule wake-up notification
   */
  async scheduleWakeUpNotification(
    userId: string,
    deviceToken: string,
    wakeTime: Date,
    sleepScore: number
  ): Promise<void> {
    const offsetMinutes = parseInt(process.env.WAKE_NOTIFICATION_OFFSET_MINUTES || '-15');
    const notificationTime = new Date(wakeTime);
    notificationTime.setMinutes(notificationTime.getMinutes() + offsetMinutes);

    const payload: NotificationPayload = {
      title: 'Good morning! ☀️',
      body: `Your sleep score: ${sleepScore}/100. ${this.getSleepScoreMessage(sleepScore)}`,
      data: {
        type: 'wake_up',
        sleep_score: sleepScore.toString(),
      },
    };

    const now = new Date();
    if (notificationTime > now) {
      const delay = notificationTime.getTime() - now.getTime();
      setTimeout(async () => {
        try {
          await this.sendNotification(userId, deviceToken, payload, 'wake_up');
        } catch (error) {
          console.error('Failed to send wake-up notification:', error);
        }
      }, delay);

      console.log(`Wake-up notification scheduled for ${notificationTime.toISOString()}`);
    }
  }

  /**
   * Schedule pre-dip notification
   */
  async schedulePreDipNotification(
    userId: string,
    deviceToken: string,
    dipTime: Date,
    preDipMinutes: number
  ): Promise<void> {
    const notificationTime = new Date(dipTime);
    notificationTime.setMinutes(notificationTime.getMinutes() - preDipMinutes);

    const dipTimeStr = dipTime.toLocaleTimeString('en-US', { 
      hour: 'numeric', 
      minute: '2-digit',
      hour12: true 
    });

    const payload: NotificationPayload = {
      title: 'Energy dip approaching',
      body: `Your energy dip is predicted at ${dipTimeStr}. Consider taking a break soon.`,
      data: {
        type: 'pre_dip',
        dip_time: dipTime.toISOString(),
      },
    };

    const now = new Date();
    if (notificationTime > now) {
      const delay = notificationTime.getTime() - now.getTime();
      setTimeout(async () => {
        try {
          await this.sendNotification(userId, deviceToken, payload, 'pre_dip');
        } catch (error) {
          console.error('Failed to send pre-dip notification:', error);
        }
      }, delay);

      console.log(`Pre-dip notification scheduled for ${notificationTime.toISOString()}`);
    }
  }

  private getSleepScoreMessage(score: number): string {
    if (score >= 85) return 'Excellent rest! Ready for a productive day.';
    if (score >= 70) return 'Good sleep. You should feel refreshed.';
    if (score >= 55) return 'Fair sleep. Consider an earlier bedtime tonight.';
    return 'Poor sleep. Prioritize recovery today.';
  }

  /**
   * Initialize daily notification scheduler
   * This runs periodically to schedule notifications for users
   */
  startScheduler() {
    cron.schedule('*/30 * * * *', () => {
      this.scheduleNotificationsForAllUsers();
    });

    console.log('Notification scheduler started (runs every 30 minutes)');
  }

  private async scheduleNotificationsForAllUsers() {
    try {
      const stmt = db.prepare(`
        SELECT u.id, u.device_token, u.pre_dip_notification_minutes, u.notifications_enabled,
               ep.wake_time, ep.dip_time, 
               ss.quality_score as sleep_score
        FROM users u
        LEFT JOIN energy_predictions ep ON u.id = ep.user_id 
          AND ep.date = date('now')
        LEFT JOIN sleep_sessions ss ON u.id = ss.user_id
        WHERE u.notifications_enabled = 1 
          AND u.device_token IS NOT NULL
        ORDER BY ss.created_at DESC
        LIMIT 1
      `);

      const users = stmt.all() as any[];

      for (const user of users) {
        if (!user.device_token) continue;

        if (user.wake_time && user.sleep_score) {
          await this.scheduleWakeUpNotification(
            user.id,
            user.device_token,
            new Date(user.wake_time),
            user.sleep_score
          );
        }

        if (user.dip_time) {
          await this.schedulePreDipNotification(
            user.id,
            user.device_token,
            new Date(user.dip_time),
            user.pre_dip_notification_minutes || 30
          );
        }
      }
    } catch (error) {
      console.error('Error scheduling notifications:', error);
    }
  }
}

export const notificationService = new NotificationService();
