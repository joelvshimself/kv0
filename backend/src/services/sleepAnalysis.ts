import { SleepSession } from '../models/database';

/**
 * Sleep Score Calculation
 * Based on multiple factors similar to RISE app methodology:
 * - Duration: How long you slept vs. individual need (7-9 hours baseline)
 * - Quality: Deep sleep and REM percentages
 * - Timing: How aligned with circadian rhythm
 * - Consistency: Regularity of sleep schedule
 */

export interface SleepScoreBreakdown {
  overall: number;
  duration: number;
  quality: number;
  timing: number;
}

export interface SleepAnalysis {
  score: SleepScoreBreakdown;
  sleep_debt_minutes: number;
  recommendation: string;
  optimal_wake_time: string;
  optimal_sleep_time: string;
}

const OPTIMAL_SLEEP_DURATION = 8 * 60; // 8 hours in minutes
const MIN_SLEEP_DURATION = 7 * 60; // 7 hours
const MAX_SLEEP_DURATION = 9 * 60; // 9 hours

export class SleepAnalysisService {
  /**
   * Calculate sleep score from a sleep session
   */
  calculateSleepScore(session: SleepSession, previousSessions: SleepSession[]): SleepScoreBreakdown {
    const durationScore = this.calculateDurationScore(session.duration_minutes);
    const qualityScore = this.calculateQualityScore(session);
    const timingScore = this.calculateTimingScore(session, previousSessions);

    const overall = Math.round(
      durationScore * 0.4 + 
      qualityScore * 0.4 + 
      timingScore * 0.2
    );

    return {
      overall: Math.max(0, Math.min(100, overall)),
      duration: Math.round(durationScore),
      quality: Math.round(qualityScore),
      timing: Math.round(timingScore),
    };
  }

  /**
   * Duration score: How close to optimal sleep duration
   */
  private calculateDurationScore(durationMinutes: number): number {
    if (durationMinutes >= MIN_SLEEP_DURATION && durationMinutes <= MAX_SLEEP_DURATION) {
      return 100;
    }
    
    if (durationMinutes < MIN_SLEEP_DURATION) {
      const deficit = MIN_SLEEP_DURATION - durationMinutes;
      return Math.max(0, 100 - (deficit / 60) * 15);
    }
    
    const excess = durationMinutes - MAX_SLEEP_DURATION;
    return Math.max(0, 100 - (excess / 60) * 10);
  }

  /**
   * Quality score: Based on sleep stages
   */
  private calculateQualityScore(session: SleepSession): number {
    if (!session.deep_sleep_minutes && !session.rem_sleep_minutes) {
      return 75;
    }

    const totalSleep = session.duration_minutes - (session.awake_minutes || 0);
    const deepPercentage = ((session.deep_sleep_minutes || 0) / totalSleep) * 100;
    const remPercentage = ((session.rem_sleep_minutes || 0) / totalSleep) * 100;

    const deepScore = Math.min(100, (deepPercentage / 20) * 100);
    const remScore = Math.min(100, (remPercentage / 25) * 100);

    return (deepScore + remScore) / 2;
  }

  /**
   * Timing score: Consistency with previous sleep schedule
   */
  private calculateTimingScore(session: SleepSession, previousSessions: SleepSession[]): number {
    if (previousSessions.length === 0) {
      return 80;
    }

    const sessionStart = new Date(session.start_time);
    const sessionHour = sessionStart.getHours() + sessionStart.getMinutes() / 60;

    const avgStartHour = previousSessions.reduce((sum, s) => {
      const start = new Date(s.start_time);
      return sum + start.getHours() + start.getMinutes() / 60;
    }, 0) / previousSessions.length;

    const variance = Math.abs(sessionHour - avgStartHour);
    
    if (variance <= 0.5) return 100;
    if (variance <= 1) return 90;
    if (variance <= 2) return 75;
    
    return Math.max(30, 100 - variance * 15);
  }

  /**
   * Calculate sleep debt based on recent sessions
   */
  calculateSleepDebt(recentSessions: SleepSession[]): number {
    if (recentSessions.length === 0) return 0;

    const totalDeficit = recentSessions.reduce((debt, session) => {
      const deficit = OPTIMAL_SLEEP_DURATION - session.duration_minutes;
      return debt + Math.max(0, deficit);
    }, 0);

    return Math.round(totalDeficit);
  }

  /**
   * Generate sleep analysis with recommendations
   */
  analyzeSleep(session: SleepSession, previousSessions: SleepSession[]): SleepAnalysis {
    const score = this.calculateSleepScore(session, previousSessions);
    const sleep_debt_minutes = this.calculateSleepDebt([session, ...previousSessions.slice(0, 6)]);

    let recommendation = '';
    if (score.overall >= 85) {
      recommendation = 'Excellent sleep! You\'re well-rested and ready for a productive day.';
    } else if (score.overall >= 70) {
      recommendation = 'Good sleep. You should feel reasonably refreshed today.';
    } else if (score.overall >= 55) {
      recommendation = 'Fair sleep. Consider going to bed earlier tonight to catch up.';
    } else {
      recommendation = 'Poor sleep. Prioritize recovery tonight and consider a short nap if needed.';
    }

    if (sleep_debt_minutes > 60) {
      recommendation += ` You have ${Math.round(sleep_debt_minutes / 60)} hours of sleep debt.`;
    }

    const endTime = new Date(session.end_time);
    const optimalWakeTime = new Date(endTime);
    optimalWakeTime.setHours(7, 0, 0, 0);
    
    const optimalSleepTime = new Date(optimalWakeTime);
    optimalSleepTime.setHours(23, 0, 0, 0);
    optimalSleepTime.setDate(optimalSleepTime.getDate() - 1);

    return {
      score,
      sleep_debt_minutes,
      recommendation,
      optimal_wake_time: optimalWakeTime.toISOString(),
      optimal_sleep_time: optimalSleepTime.toISOString(),
    };
  }

  /**
   * Calculate quality score from HealthKit data
   * HealthKit provides sleep stages, which we can use for accurate scoring
   */
  calculateQualityFromHealthKit(
    deepMinutes: number,
    remMinutes: number,
    lightMinutes: number,
    awakeMinutes: number
  ): number {
    const totalMinutes = deepMinutes + remMinutes + lightMinutes + awakeMinutes;
    
    const deepPercentage = (deepMinutes / totalMinutes) * 100;
    const remPercentage = (remMinutes / totalMinutes) * 100;
    const awakePercentage = (awakeMinutes / totalMinutes) * 100;

    let qualityScore = 0;
    qualityScore += Math.min(25, (deepPercentage / 20) * 25);
    qualityScore += Math.min(25, (remPercentage / 25) * 25);
    qualityScore += Math.max(0, 50 - awakePercentage * 2);

    return Math.round(Math.max(0, Math.min(100, qualityScore)));
  }
}

export const sleepAnalysisService = new SleepAnalysisService();
