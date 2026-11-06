# kv0

An iOS companion for people who work hard and care about their sleep.
One screen tells you how many hours you have until your next energy dip, how you slept,
and how long you've been driving. The visual language is adapted from
[Nova30](https://nova30.lat): a dark sky, bone type and orange orbits.

kv0 has no backend. Sleep is read from Apple Health, driving is detected by the iPhone's
motion sensors (no GPS), every score and prediction is computed on the iPhone, and
reminders are local notifications. Nothing leaves the device.

## The day it follows

kv0 is built for people whose work is driving. It picks the moment on its own; there is
nothing to toggle.

1. **Morning**: from waking until your first drive. Last night's sleep from Apple Health.
2. **Working**: from your first drive. Counts down the hours to your predicted dip.
3. **Break due**: when the dip is within 90 minutes, or after two hours behind the wheel
   without a ten-minute stop.
4. **Finish work**: after an hour parked in the evening (from 17:00). The sleep you need
   to recover tonight.

Without Motion & Fitness access the moments fall back to the clock. Until Apple Health has
sleep to share, the screen shows a sample day and says so.

## Run it

Requires Xcode 16+ and iOS 17. The Xcode project is generated from `project.yml`, so
regenerate it after adding or removing files:

```sh
xcodegen generate
open kv0.xcodeproj
```

Set your signing team in Xcode (Signing & Capabilities). HealthKit needs a real device
with sleep data; the simulator shows the sample day.

## How it works

All of this lives in `kv0/Services/SleepEngine.swift`.

### Reading sleep

`HealthKitManager` reads the last ten days of sleep analysis samples and groups them
into nights (a gap of two hours starts a new night). When the iPhone and an Apple Watch
both logged the same night, it keeps one source, preferring the one with sleep stages,
so the night isn't counted twice. Time in bed is not counted as sleep, except for
iPhone-only Sleep Schedule data, where it is the only estimate available.

### Sleep score

- **Duration (40%)**: full marks between 7 and 9 hours.
- **Quality (40%)**: deep sleep against a 20% target and REM against 25%. Nights
  without stage data get a neutral 75.
- **Timing (20%)**: how close bedtime was to your recent average.

### Energy dip

A two-process model: a circadian rhythm, sleep pressure that builds while awake, and
morning sleep inertia. The dip lands about 7.5 hours after waking and up to 1.5 hours
earlier as the week's sleep debt grows.

### Driving

`DriveTracker` asks CoreMotion for today's activity history, which iOS records whether
or not kv0 is running, and for live updates while the app is open. Stops under five
minutes (lights, queues) stay part of a drive, and drives under three minutes are
dropped as misreads. Driving today is the sum of the drives since an hour before waking.

### Reminders

A local notification before the predicted dip (15 to 60 minutes, set in Settings). It is
rescheduled whenever sleep is re-read, which happens each time the app comes forward.

Design tokens and principles live in [DESIGN.md](DESIGN.md). Space Grotesk is bundled
under the SIL Open Font License (`kv0/Resources/Fonts/OFL.txt`).
