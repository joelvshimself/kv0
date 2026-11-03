# kv0

An iOS companion for people who work hard and care about their sleep.
One screen tells you how many hours you have until your next energy dip, how you slept,
and how long your drive took. The visual language is adapted from
[Nova30](https://nova30.lat): a dark sky, bone type and orange orbits.

## Features

✨ **Real Sleep Tracking**: Integrates with Apple HealthKit to read actual sleep data  
📊 **Sleep Score Analysis**: Multi-factor scoring based on duration, quality, and timing  
🌙 **Circadian Rhythm Model**: Predicts your afternoon energy dip using a two-process sleep model  
🔔 **Smart Notifications**: Wake-up alerts with sleep scores and pre-dip reminders  
📈 **Energy Predictions**: Real-time alertness curve based on your sleep debt and wake time  
☁️ **Backend API**: Node.js service for data persistence and analysis  

## The day it follows

1. **Morning**: your sleep score from HealthKit and a short note to start the day.
2. **Working**: hours left until your predicted dip, on a personalized alertness curve.
3. **Break due**: a nudge to step away after long stretches, with rest ideas.
4. **Home**: appreciation for the day and the sleep you need to recover.

Switch between moments with the picker at the bottom. All data is now **real and functional**.

## Architecture

- **iOS App** (Swift/SwiftUI): HealthKit integration, notifications, API client
- **Backend API** (Node.js/TypeScript): Sleep analysis, circadian predictions, notification scheduler
- **Database** (SQLite): User data, sleep sessions, energy predictions

## Quick Start

### iOS App

Requires Xcode 15+ and iOS 17.

```sh
# Generate Xcode project
xcodegen generate

# Open in Xcode
open kv0.xcodeproj
```

**First launch**: The app will request HealthKit and notification permissions.

### Backend Server

Requires Docker and Docker Compose.

```sh
# Start backend service
docker-compose up -d

# Check health
curl http://localhost:3000/api/health
```

**For production deployment**, see [DEPLOYMENT.md](DEPLOYMENT.md).

## Configuration

### App Settings
- Tap the gear icon to configure:
  - Backend API URL (default: `http://localhost:3000/api`)
  - Notification preferences
  - Pre-dip notification timing (default: 30 minutes before)

### Backend Environment
Copy `backend/.env.example` to `backend/.env` and configure:
- `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_PATH` - Apple Push credentials
- `PRE_DIP_NOTIFICATION_MINUTES` - Lead time for dip notifications (default: 30)

## How It Works

### Sleep Score Calculation
Combines three factors:
- **Duration (40%)**: Proximity to 7-9 hour optimal range
- **Quality (40%)**: Deep sleep and REM percentages from HealthKit
- **Timing (20%)**: Consistency with your sleep schedule

### Energy Dip Prediction
Uses the two-process model:
- **Process S**: Homeostatic sleep pressure building during wakefulness
- **Process C**: Circadian 24-hour rhythm

**Formula**: `dip_time = wake_time + 7.5 hours - (sleep_debt * 0.15)`

The afternoon dip typically occurs 7-9 hours after waking. More sleep debt shifts it earlier.

### Notifications

1. **Wake-up Notification**: Sent 15 minutes after wake time with your sleep score
2. **Pre-dip Notification**: Sent 30 minutes before predicted energy dip (configurable)

Both are scheduled automatically when sleep data syncs from HealthKit.

## Development

### Regenerate Project
```sh
xcodegen generate
```

### Backend Development
```sh
cd backend
npm install
npm run dev
```

### Run Tests
```sh
cd backend
npm test
```

## What Joel Needs to Deploy

To run the full system in production:

1. **APNs Credentials** (for push notifications)
   - Generate from Apple Developer Portal
   - Provide Key ID, Team ID, and .p8 file

2. **Server/Hosting**
   - Any cloud VM or container service
   - Minimum: 1 CPU, 512MB RAM

3. **Domain Name** (optional but recommended)
   - Point DNS to backend server

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete setup instructions.

## Files Added/Modified

### New Backend
- `backend/` - Complete Node.js/TypeScript API service
- `docker-compose.yml` - Container orchestration

### New iOS Services
- `kv0/Services/HealthKitManager.swift` - HealthKit integration
- `kv0/Services/APIClient.swift` - Backend API client
- `kv0/Services/DataSyncManager.swift` - Sync coordinator
- `kv0/Services/AppState.swift` - App-wide state management
- `kv0/Services/NotificationManager.swift` - Local & remote notifications

### Updated iOS Components
- `kv0/App/kv0App.swift` - App initialization and delegation
- `kv0/Views/ContentView.swift` - Real data integration
- `kv0/Views/Components/SettingsSheet.swift` - User preferences
- `kv0/Views/Components/TimeGraphView.swift` - Real alertness curve
- `kv0/Models/JourneyState.swift` - Extended snapshot model

### Configuration
- `project.yml` - Added HealthKit entitlements
- `kv0/kv0.entitlements` - HealthKit capabilities
- `kv0/Info.plist` - HealthKit usage descriptions

### Documentation
- `DEPLOYMENT.md` - Complete deployment guide
- `backend/README.md` - API documentation

Design tokens and principles live in [DESIGN.md](DESIGN.md). Space Grotesk is bundled
under the SIL Open Font License (`kv0/Resources/Fonts/OFL.txt`).
