# kv0 Deployment Guide

This guide explains how to deploy and run the kv0 backend service that powers real sleep tracking, energy predictions, and notifications.

## Architecture Overview

kv0 consists of two main components:

1. **iOS App** (Swift/SwiftUI) - The client application
   - HealthKit integration for sleep data
   - Local and remote notifications
   - API client for backend communication

2. **Backend API** (Node.js/TypeScript) - The server
   - SQLite database for data persistence
   - Sleep analysis and circadian rhythm prediction
   - Notification scheduling (APNs for iOS, FCM for Android)
   - RESTful API for data sync

## Prerequisites

### For Backend Deployment

- Docker and Docker Compose (recommended)
- OR Node.js 20+ and npm (for local development)

### For iOS App

- Xcode 15+ and iOS 17+
- Apple Developer account (for push notifications)

### Required Credentials

1. **Apple Push Notification Service (APNs)** - Required for iOS push notifications
   - APNs Key ID
   - APNs Team ID
   - APNs Auth Key (.p8 file)

2. **Firebase Cloud Messaging (FCM)** - Optional, for Android support
   - Firebase service account JSON

## Backend Deployment

### Option 1: Docker Compose (Recommended)

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd kv0
   ```

2. **Create environment file**
   ```bash
   cp backend/.env.example backend/.env
   ```

3. **Configure environment variables**
   Edit `backend/.env`:
   ```env
   PORT=3000
   DATABASE_PATH=/data/kv0.db

   # APNs Configuration (REQUIRED for iOS notifications)
   APNS_KEY_ID=your_key_id_here
   APNS_TEAM_ID=your_team_id_here
   APNS_KEY_PATH=/app/certs/AuthKey_XXXXXXXX.p8
   APNS_BUNDLE_ID=com.kv0.app
   APNS_PRODUCTION=false

   # FCM Configuration (optional, for Android)
   FIREBASE_SERVICE_ACCOUNT_PATH=/app/certs/firebase-service-account.json

   # Notification Settings
   PRE_DIP_NOTIFICATION_MINUTES=30
   WAKE_NOTIFICATION_OFFSET_MINUTES=-15
   ```

4. **Place certificate files**
   ```bash
   mkdir -p certs
   # Copy your APNs .p8 key file to certs/
   cp /path/to/AuthKey_XXXXXXXX.p8 certs/
   # (Optional) Copy Firebase service account JSON
   cp /path/to/firebase-service-account.json certs/
   ```

5. **Build and start the service**
   ```bash
   docker-compose up -d
   ```

6. **Verify deployment**
   ```bash
   curl http://localhost:3000/api/health
   ```

   Expected response:
   ```json
   {
     "status": "healthy",
     "timestamp": "2026-11-03T08:54:00.000Z"
   }
   ```

### Option 2: Local Development

1. **Install dependencies**
   ```bash
   cd backend
   npm install
   ```

2. **Set up environment**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Build and run**
   ```bash
   npm run build
   npm start
   ```

   Or for development with auto-reload:
   ```bash
   npm run dev
   ```

### Production Deployment

For production deployment on cloud platforms:

#### Using Docker on AWS/GCP/Azure

1. Build the Docker image:
   ```bash
   docker build -t kv0-backend ./backend
   ```

2. Push to container registry:
   ```bash
   docker tag kv0-backend your-registry/kv0-backend:latest
   docker push your-registry/kv0-backend:latest
   ```

3. Deploy using your platform's container service (ECS, Cloud Run, Container Apps)

#### Environment Variables for Production

Set these environment variables in your deployment:
- `PORT` - Server port (default: 3000)
- `DATABASE_PATH` - Database file path
- `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_PATH` - APNs credentials
- `APNS_PRODUCTION=true` - Use production APNs
- `PRE_DIP_NOTIFICATION_MINUTES` - Lead time for dip notifications (default: 30)

## iOS App Setup

### 1. Configure Bundle ID and Signing

1. Open `kv0.xcodeproj` in Xcode
2. Update the bundle identifier in `project.yml`:
   ```yaml
   PRODUCT_BUNDLE_IDENTIFIER: com.yourcompany.kv0
   ```
3. Run `xcodegen generate` to update the project
4. In Xcode, select your team for code signing

### 2. Enable Push Notifications

1. Go to Apple Developer Portal
2. Create an APNs Key:
   - Keys → Create a key
   - Enable "Apple Push Notifications service (APNs)"
   - Download the .p8 file
   - Note the Key ID and Team ID

3. In Xcode:
   - Select project → Target → Signing & Capabilities
   - Add "Push Notifications" capability
   - Add "Background Modes" capability
   - Enable "Remote notifications"

### 3. Enable HealthKit

HealthKit is already configured in the project, but you need to:
1. Verify `kv0.entitlements` includes HealthKit
2. Ensure Info.plist has usage descriptions (already added)

### 4. Configure Backend URL

In the app settings:
1. Launch the app
2. Tap the gear icon (Settings)
3. Update "API URL" to your backend URL
   - Local: `http://localhost:3000/api`
   - Remote: `https://your-server.com/api`

## API Endpoints

### User Management
- `POST /api/users` - Register or update user
- `GET /api/users/:id` - Get user details

### Sleep Data
- `POST /api/sleep` - Submit sleep session (from HealthKit)
- `GET /api/sleep/:userId` - Get sleep history

### Energy Predictions
- `GET /api/energy/:userId` - Get today's energy prediction and dip time

### Journey Logs
- `POST /api/journey` - Log commute/journey time
- `GET /api/journey/:userId` - Get journey history

### Dashboard
- `GET /api/dashboard/:userId` - Get all data for today

## Notifications

### How Notifications Work

1. **Wake-up Notification**
   - Sent in the morning (default: 15 minutes before predicted wake time)
   - Includes sleep score from last night
   - Triggered by sleep data sync

2. **Pre-dip Notification**
   - Sent before afternoon energy dip (default: 30 minutes before)
   - Calculated from circadian rhythm model
   - Based on wake time and sleep debt

### Notification Configuration

Set in backend `.env`:
```env
# Send wake notification 15 minutes before wake time
WAKE_NOTIFICATION_OFFSET_MINUTES=-15

# Send dip notification 30 minutes before dip
PRE_DIP_NOTIFICATION_MINUTES=30
```

Or adjust per-user in iOS app settings.

### Testing Notifications

For development:
1. Set `APNS_PRODUCTION=false` in backend
2. Use a development provisioning profile in Xcode
3. Build and run on a physical device (required for push)
4. Backend logs will show notification scheduling

## Sleep Score & Energy Model

### Sleep Score Calculation

The sleep score (0-100) combines:
- **Duration (40%)**: How close to 7-9 hours optimal range
- **Quality (40%)**: Deep sleep and REM percentages
- **Timing (20%)**: Consistency with previous sleep schedule

### Circadian Rhythm Prediction

The energy dip prediction uses a two-process model:
- **Process S (Homeostatic)**: Sleep pressure builds while awake
- **Process C (Circadian)**: 24-hour biological rhythm

**Dip Time Formula**:
```
base_hours_after_wake = 7.5
sleep_debt_hours = sleep_debt_minutes / 60
dip_offset = base_hours_after_wake - (sleep_debt_hours * 0.15)
dip_time = wake_time + dip_offset hours
```

**Interpretation**: The afternoon dip typically occurs 7-9 hours after waking. More sleep debt shifts it earlier.

## Data Flow

1. **Morning: Sleep Data Sync**
   - iOS app reads sleep from HealthKit
   - Sends to backend via `POST /api/sleep`
   - Backend calculates sleep score and stores data
   - Backend predicts energy curve and dip time
   - Backend schedules notifications for the day

2. **Throughout Day: App Updates**
   - App fetches `GET /api/dashboard/:userId`
   - Displays real-time energy prediction
   - Shows hours until dip
   - Updates alertness curve

3. **Notifications**
   - Backend scheduler runs every 30 minutes
   - Checks users with notifications enabled
   - Sends push via APNs or FCM

## Troubleshooting

### Backend Issues

**Database errors**
```bash
# Check database location
ls -la data/

# Check permissions
chmod 644 data/kv0.db

# Reset database (WARNING: deletes all data)
rm data/kv0.db
docker-compose restart
```

**Notification failures**
- Verify APNs credentials are correct
- Check device token is registered: `GET /api/users/:userId`
- Check notification logs: `SELECT * FROM notifications_log ORDER BY created_at DESC LIMIT 10;`

### iOS App Issues

**HealthKit not working**
- Must run on a physical device
- Check HealthKit authorization in Settings → Privacy & Security → Health
- Verify sleep data exists in Apple Health app

**Push notifications not received**
- Must use a physical device (simulator doesn't support push)
- Check notification permissions in iOS Settings
- Verify device token in app settings
- Check backend logs for APNs errors

**API connection failed**
- Verify backend URL in app settings
- If using localhost, ensure backend is running
- For remote server, check firewall/network access

## Security Notes

⚠️ **Do NOT commit the following files:**
- `.env` files with credentials
- APNs `.p8` key files
- Firebase service account JSON
- Database files with user data

These are already in `.gitignore`.

## What Joel Needs to Provide

To fully deploy and run the system, Joel needs:

1. **APNs Credentials** (Required for iOS push notifications)
   - Generate from Apple Developer Portal → Certificates, Identifiers & Profiles → Keys
   - Download the .p8 file
   - Provide Key ID and Team ID

2. **Server/Hosting** (Required for backend)
   - Any cloud VM or container service
   - Public IP or domain name
   - Minimum: 1 CPU, 512MB RAM, 10GB storage

3. **Domain Name** (Optional but recommended)
   - For production deployment
   - Configure DNS to point to backend server

4. **Firebase Account** (Optional, only if Android support is needed)
   - Create project at console.firebase.google.com
   - Download service account JSON

## Next Steps

1. ✅ Backend is built and containerized
2. ✅ iOS app has HealthKit, notifications, and API integration
3. ⏳ Joel provides APNs credentials
4. ⏳ Deploy backend to server
5. ⏳ Configure app with production backend URL
6. ⏳ Test on physical device with real sleep data

---

For questions or issues, check the logs:
```bash
# Backend logs
docker-compose logs -f kv0-backend

# Or if running locally
tail -f backend/logs/app.log
```
