# kv0 Backend API

RESTful API service for kv0 sleep and energy tracking application.

## Features

- **Sleep Analysis**: Calculate sleep scores from HealthKit data using duration, quality, and timing metrics
- **Circadian Rhythm Prediction**: Two-process model predicting afternoon energy dip based on wake time and sleep debt
- **Notification Scheduling**: Automated wake-up and pre-dip notifications via APNs/FCM
- **Data Persistence**: SQLite database for user profiles, sleep sessions, and predictions
- **RESTful API**: JSON endpoints for mobile app integration

## Tech Stack

- **Runtime**: Node.js 20 (TypeScript)
- **Framework**: Express
- **Database**: SQLite (better-sqlite3)
- **Scheduling**: node-cron
- **Push Notifications**: 
  - APNs (Apple Push Notification service) for iOS
  - FCM (Firebase Cloud Messaging) for Android

## Quick Start

### Using Docker Compose

```bash
docker-compose up -d
```

### Local Development

```bash
cd backend
npm install
npm run dev
```

Visit http://localhost:3000 for API documentation.

## Environment Variables

Copy `.env.example` to `.env` and configure:

```env
PORT=3000
DATABASE_PATH=./data/kv0.db

# APNs (required for iOS push)
APNS_KEY_ID=your_key_id
APNS_TEAM_ID=your_team_id
APNS_KEY_PATH=./certs/AuthKey_XXXXXXXX.p8
APNS_BUNDLE_ID=com.kv0.app
APNS_PRODUCTION=false

# Notification timing
PRE_DIP_NOTIFICATION_MINUTES=30
WAKE_NOTIFICATION_OFFSET_MINUTES=-15
```

## API Endpoints

### Health Check
```bash
GET /api/health
```

### User Management
```bash
POST /api/users
{
  "id": "uuid",
  "device_token": "apns_token",
  "timezone": "America/New_York",
  "pre_dip_notification_minutes": 30,
  "notifications_enabled": true
}

GET /api/users/:id
```

### Sleep Data
```bash
POST /api/sleep
{
  "user_id": "uuid",
  "start_time": "2026-11-02T23:00:00.000Z",
  "end_time": "2026-11-03T07:20:00.000Z",
  "duration_minutes": 500,
  "deep_sleep_minutes": 120,
  "rem_sleep_minutes": 100,
  "light_sleep_minutes": 250,
  "awake_minutes": 30,
  "source": "HealthKit"
}

GET /api/sleep/:userId?days=7
```

### Energy Predictions
```bash
GET /api/energy/:userId
```

Returns:
- Wake time
- Predicted dip time
- Sleep debt
- Alertness curve (hourly data points)
- Hours until dip

### Journey Logs
```bash
POST /api/journey
{
  "user_id": "uuid",
  "date": "2026-11-03",
  "duration_minutes": 35,
  "start_time": "2026-11-03T08:00:00.000Z",
  "end_time": "2026-11-03T08:35:00.000Z"
}

GET /api/journey/:userId?days=7
```

### Dashboard (All Data)
```bash
GET /api/dashboard/:userId
```

Returns:
- Last sleep session
- Recent sleep history (7 days)
- Today's energy prediction
- Today's journey logs

## Sleep Score Algorithm

The sleep score (0-100) is calculated from three components:

### Duration Score (40%)
- Optimal: 7-9 hours = 100 points
- < 7 hours: Penalty of 15 points per hour deficit
- > 9 hours: Penalty of 10 points per hour excess

### Quality Score (40%)
Based on sleep stages from HealthKit:
- Deep sleep: 20-25% optimal
- REM sleep: 20-25% optimal
- Awake time: <5% optimal

### Timing Score (20%)
Consistency with previous sleep schedule:
- Within 30 min of average: 100 points
- Within 1 hour: 90 points
- Within 2 hours: 75 points
- Greater variance: decreasing points

## Circadian Rhythm Model

Uses the **two-process model** of sleep regulation:

### Process S (Homeostatic)
Sleep pressure accumulates during wakefulness, increasing fatigue.

### Process C (Circadian)
24-hour biological clock with predictable peaks and troughs.

### Dip Prediction
```
base_offset = 7.5 hours after wake
sleep_debt_adjustment = -0.15 * (sleep_debt_hours)
dip_time = wake_time + base_offset + sleep_debt_adjustment
```

The afternoon dip typically occurs 7-9 hours after waking. Higher sleep debt shifts it earlier.

### Alertness Curve
Generated using:
```javascript
circadian_component = 0.55 + 0.35 * sin((hour - wake_hour - 3) / 24 * 2π)
dip_component = 0.28 * exp(-((hour - dip_hour)² / 2.2))
wake_inertia = 0.3 * exp(-(hours_awake / 1.2))
homeostatic_pressure = (hours_awake / 16) * 0.2 * (1 + sleep_debt_factor)

alertness = circadian - dip - wake_inertia - homeostatic_pressure
```

## Notification Scheduling

The scheduler runs every 30 minutes checking for users with:
- Notifications enabled
- Device token registered
- Energy predictions for today

### Wake-up Notification
- Triggered: When sleep data is submitted
- Timing: Configurable offset from wake time (default: -15 minutes)
- Content: Sleep score and assessment message

### Pre-dip Notification
- Triggered: When energy prediction is created
- Timing: N minutes before predicted dip (default: 30)
- Content: Dip time and suggestion to take a break

## Database Schema

### users
- id (TEXT, primary key)
- device_token (TEXT)
- timezone (TEXT)
- wake_time, sleep_time (TEXT)
- pre_dip_notification_minutes (INTEGER)
- notifications_enabled (INTEGER)
- created_at, updated_at (TEXT)

### sleep_sessions
- id (INTEGER, auto-increment)
- user_id (TEXT)
- start_time, end_time (TEXT)
- duration_minutes (INTEGER)
- quality_score (REAL)
- deep_sleep_minutes, rem_sleep_minutes, light_sleep_minutes, awake_minutes (INTEGER)
- source (TEXT)
- created_at (TEXT)

### energy_predictions
- id (INTEGER, auto-increment)
- user_id (TEXT)
- date (TEXT)
- wake_time, dip_time (TEXT)
- sleep_debt_minutes (INTEGER)
- circadian_phase (REAL)
- alertness_curve (TEXT, JSON)
- created_at (TEXT)

### journey_logs
- id (INTEGER, auto-increment)
- user_id (TEXT)
- date (TEXT)
- duration_minutes (INTEGER)
- start_time, end_time (TEXT)
- created_at (TEXT)

### notifications_log
- id (INTEGER, auto-increment)
- user_id (TEXT)
- notification_type (TEXT)
- scheduled_time, sent_time (TEXT)
- status (TEXT)
- error (TEXT)
- created_at (TEXT)

## Development

### Build
```bash
npm run build
```

### Run Tests
```bash
npm test
```

### Watch Mode
```bash
npm run dev
```

## Production Deployment

See [DEPLOYMENT.md](../DEPLOYMENT.md) for full deployment guide.

Quick checklist:
- [ ] Set `APNS_PRODUCTION=true`
- [ ] Use production APNs credentials
- [ ] Configure firewall (allow port 3000)
- [ ] Set up database backups
- [ ] Configure monitoring/logging
- [ ] Use HTTPS reverse proxy (nginx/traefik)

## Monitoring

### Health Check
```bash
curl http://localhost:3000/api/health
```

### Database Status
```bash
sqlite3 data/kv0.db "SELECT COUNT(*) FROM users;"
sqlite3 data/kv0.db "SELECT COUNT(*) FROM sleep_sessions;"
sqlite3 data/kv0.db "SELECT COUNT(*) FROM energy_predictions;"
```

### Recent Notifications
```bash
sqlite3 data/kv0.db "SELECT * FROM notifications_log ORDER BY created_at DESC LIMIT 10;"
```

## License

See LICENSE file in repository root.
