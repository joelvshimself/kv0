import Database from 'better-sqlite3';
import path from 'path';
import fs from 'fs';

const dbPath = process.env.DATABASE_PATH || './data/kv0.db';
const dbDir = path.dirname(dbPath);

if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

export const db: Database.Database = new Database(dbPath);

db.pragma('journal_mode = WAL');

export function initializeDatabase() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      device_token TEXT,
      timezone TEXT NOT NULL DEFAULT 'UTC',
      wake_time TEXT,
      sleep_time TEXT,
      pre_dip_notification_minutes INTEGER DEFAULT 30,
      notifications_enabled INTEGER DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS sleep_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      duration_minutes INTEGER NOT NULL,
      quality_score REAL,
      deep_sleep_minutes INTEGER,
      rem_sleep_minutes INTEGER,
      light_sleep_minutes INTEGER,
      awake_minutes INTEGER,
      source TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS energy_predictions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      date TEXT NOT NULL,
      wake_time TEXT NOT NULL,
      dip_time TEXT NOT NULL,
      sleep_debt_minutes INTEGER NOT NULL,
      circadian_phase REAL NOT NULL,
      alertness_curve TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(user_id, date)
    );

    CREATE TABLE IF NOT EXISTS journey_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      date TEXT NOT NULL,
      duration_minutes INTEGER NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS notifications_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      notification_type TEXT NOT NULL,
      scheduled_time TEXT NOT NULL,
      sent_time TEXT,
      status TEXT NOT NULL,
      error TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_sleep_sessions_user_date ON sleep_sessions(user_id, start_time);
    CREATE INDEX IF NOT EXISTS idx_energy_predictions_user_date ON energy_predictions(user_id, date);
    CREATE INDEX IF NOT EXISTS idx_journey_logs_user_date ON journey_logs(user_id, date);
    CREATE INDEX IF NOT EXISTS idx_notifications_log_user_date ON notifications_log(user_id, scheduled_time);
  `);

  console.log('Database initialized successfully');
}

export interface User {
  id: string;
  device_token?: string;
  timezone: string;
  wake_time?: string;
  sleep_time?: string;
  pre_dip_notification_minutes: number;
  notifications_enabled: boolean;
  created_at: string;
  updated_at: string;
}

export interface SleepSession {
  id?: number;
  user_id: string;
  start_time: string;
  end_time: string;
  duration_minutes: number;
  quality_score?: number;
  deep_sleep_minutes?: number;
  rem_sleep_minutes?: number;
  light_sleep_minutes?: number;
  awake_minutes?: number;
  source: string;
  created_at?: string;
}

export interface EnergyPrediction {
  id?: number;
  user_id: string;
  date: string;
  wake_time: string;
  dip_time: string;
  sleep_debt_minutes: number;
  circadian_phase: number;
  alertness_curve: string;
  created_at?: string;
}

export interface JourneyLog {
  id?: number;
  user_id: string;
  date: string;
  duration_minutes: number;
  start_time: string;
  end_time: string;
  created_at?: string;
}

export interface NotificationLog {
  id?: number;
  user_id: string;
  notification_type: string;
  scheduled_time: string;
  sent_time?: string;
  status: string;
  error?: string;
  created_at?: string;
}
