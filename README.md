# kv0

An iOS companion for people who work hard and care about their sleep.
One screen tells you how many hours you have until your next energy dip, how you slept,
and how long your drive took. The visual language is adapted from
[Nova30](https://nova30.lat): a dark sky, bone type and orange orbits.

## The day it follows

1. **Morning**: sleep score from Apple Health (RISE-style debt model) and a short note.
2. **Working**: live hours left until your predicted dip on a personalized alertness curve.
3. **Break due**: a nudge after long stretches without a pause, with rest ideas.
4. **Home**: recovery sleep target from remaining sleep debt.

The journey advances from the clock and last wake time by default. Use the picker to
preview another moment; Settings → **Follow live day** returns to automatic mode.

## Live data

- **Apple Health** — sleep analysis (+ overnight heart rate when available) → predicted sleep score.
- **Circadian engine** — dip ~7.5h after wake, clamped to early/mid afternoon; curve shifts with debt.
- **Notifications** — morning wake summary, and an alert **30 hours before** your next dip.
- Without Health, kv0 still runs on local time with an estimated score until you connect.

Open **Settings** (gear) to connect Health, enable notifications, and switch language.

## Run

Requires Xcode 15+ and iOS 17. HealthKit needs a physical device (or a simulator with
sample sleep data) and an Apple Developer team with the HealthKit capability.

```sh
xcodegen generate
open kv0.xcodeproj
```

## Backend

An optional Node.js service for persistence, analysis, and push scheduling lives in
`backend/`. Start it with Docker:

```sh
docker-compose up -d
curl http://localhost:3000/api/health
```

Production setup is in [DEPLOYMENT.md](DEPLOYMENT.md). API details are in
[backend/README.md](backend/README.md).

Design tokens and principles live in [DESIGN.md](DESIGN.md). Space Grotesk is bundled
under the SIL Open Font License (`kv0/Resources/Fonts/OFL.txt`).
