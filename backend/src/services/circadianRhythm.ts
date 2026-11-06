import { SleepSession } from '../models/database';

/**
 * Circadian Rhythm Prediction Service
 * 
 * Based on the two-process model of sleep regulation:
 * - Process S (Sleep homeostasis): Sleep pressure builds while awake
 * - Process C (Circadian rhythm): 24-hour biological clock
 * 
 * The afternoon "dip" typically occurs 7-9 hours after waking,
 * around 2-4 PM for most people, but varies based on:
 * - Individual chronotype (morning lark vs night owl)
 * - Recent sleep patterns
 * - Sleep debt
 */

export interface AlertnessPoint {
  hour: number;
  level: number;
}

export interface CircadianPrediction {
  wake_time: string;
  dip_time: string;
  peak_time: string;
  evening_decline_time: string;
  alertness_curve: AlertnessPoint[];
  sleep_debt_impact: number;
}

export class CircadianRhythmService {
  /**
   * Predict the afternoon energy dip time based on wake time and sleep debt
   */
  predictDipTime(wakeTime: Date, sleepDebtMinutes: number): Date {
    const dipTime = new Date(wakeTime);
    
    const baseHoursAfterWake = 7.5;
    const sleepDebtHours = sleepDebtMinutes / 60;
    const dipOffset = baseHoursAfterWake - (sleepDebtHours * 0.15);
    
    dipTime.setMinutes(dipTime.getMinutes() + dipOffset * 60);
    
    return dipTime;
  }

  /**
   * Generate full alertness curve for the day
   */
  generateAlertnessCurve(
    wakeTime: Date,
    dipTime: Date,
    sleepDebtMinutes: number
  ): AlertnessPoint[] {
    const wakeHour = wakeTime.getHours() + wakeTime.getMinutes() / 60;
    const dipHour = dipTime.getHours() + dipTime.getMinutes() / 60;
    const sleepDebtFactor = Math.min(1, sleepDebtMinutes / (3 * 60));
    
    const curve: AlertnessPoint[] = [];
    
    for (let hour = wakeHour; hour <= 24; hour += 0.25) {
      const hoursAwake = hour - wakeHour;
      
      const circadianComponent = 0.55 + 0.35 * Math.sin((hour - (wakeHour + 3)) / 24 * 2 * Math.PI);
      
      const dipMagnitude = 0.28;
      const dipWidth = 2.2;
      const dipComponent = dipMagnitude * Math.exp(-Math.pow(hour - dipHour, 2) / dipWidth);
      
      const wakeinertiaDecay = 0.3 * Math.exp(-hoursAwake / 1.2);
      
      const homeostaticPressure = (hoursAwake / 16) * 0.2 * (1 + sleepDebtFactor);
      
      let level = circadianComponent - dipComponent - wakeinertiaDecay - homeostaticPressure;
      level = Math.max(0.05, Math.min(1.0, level));
      
      curve.push({
        hour: Math.round(hour * 100) / 100,
        level: Math.round(level * 100) / 100,
      });
    }
    
    return curve;
  }

  /**
   * Create a full circadian prediction for the day
   */
  predictDayEnergy(
    lastSleepSession: SleepSession,
    sleepDebtMinutes: number
  ): CircadianPrediction {
    const wakeTime = new Date(lastSleepSession.end_time);
    const dipTime = this.predictDipTime(wakeTime, sleepDebtMinutes);
    
    const peakTime = new Date(wakeTime);
    peakTime.setHours(peakTime.getHours() + 3);
    
    const eveningDeclineTime = new Date(wakeTime);
    eveningDeclineTime.setHours(19, 0, 0, 0);
    
    const alertness_curve = this.generateAlertnessCurve(wakeTime, dipTime, sleepDebtMinutes);
    
    return {
      wake_time: wakeTime.toISOString(),
      dip_time: dipTime.toISOString(),
      peak_time: peakTime.toISOString(),
      evening_decline_time: eveningDeclineTime.toISOString(),
      alertness_curve,
      sleep_debt_impact: Math.round(sleepDebtMinutes / 60 * 100) / 100,
    };
  }

  /**
   * Calculate hours until next dip from current time
   */
  calculateHoursUntilDip(dipTime: Date, currentTime: Date = new Date()): number {
    const diffMs = dipTime.getTime() - currentTime.getTime();
    const diffHours = diffMs / (1000 * 60 * 60);
    return Math.max(0, Math.round(diffHours * 10) / 10);
  }

  /**
   * Determine which journey state the user is in based on time of day
   */
  determineJourneyState(
    currentTime: Date,
    wakeTime: Date,
    dipTime: Date,
    lastBreakTime?: Date
  ): 'morning' | 'working' | 'breakDue' | 'finishWork' {
    const hoursAwake = (currentTime.getTime() - wakeTime.getTime()) / (1000 * 60 * 60);
    const currentHour = currentTime.getHours();
    
    if (hoursAwake < 2) {
      return 'morning';
    }
    
    if (currentHour >= 18) {
      return 'finishWork';
    }
    
    if (lastBreakTime) {
      const hoursSinceBreak = (currentTime.getTime() - lastBreakTime.getTime()) / (1000 * 60 * 60);
      if (hoursSinceBreak >= 2.5) {
        return 'breakDue';
      }
    }
    
    return 'working';
  }

  /**
   * Estimate chronotype based on average sleep/wake times
   * Returns a value from -1 (extreme evening) to 1 (extreme morning)
   */
  estimateChronotype(recentSessions: SleepSession[]): number {
    if (recentSessions.length === 0) return 0;

    const avgWakeHour = recentSessions.reduce((sum, session) => {
      const wakeTime = new Date(session.end_time);
      return sum + wakeTime.getHours() + wakeTime.getMinutes() / 60;
    }, 0) / recentSessions.length;

    if (avgWakeHour < 6.5) return 1;
    if (avgWakeHour < 7.5) return 0.5;
    if (avgWakeHour < 8.5) return 0;
    if (avgWakeHour < 9.5) return -0.5;
    return -1;
  }
}

export const circadianRhythmService = new CircadianRhythmService();
