# kv0

A calm iOS companion for people who work hard and care about their sleep.
One screen tells you how many hours you have until your next energy dip, how you slept,
and how long your drive took, drawn as ink on washi paper.

## The day it follows

1. **Morning**: your sleep score and a short note to start the day.
2. **Working**: hours left until your next dip, on an alertness curve.
3. **Break due**: a nudge to step away after long stretches, with rest ideas.
4. **Home**: appreciation for the day and the sleep you need to recover.

Switch between moments with the picker at the bottom. Data is mocked for now.

## Run

Requires Xcode 15+ and iOS 17.

```sh
open kv0.xcodeproj
```

The project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):
`xcodegen generate`.

Design tokens and principles live in [DESIGN.md](DESIGN.md).
