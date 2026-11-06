import Foundation

struct CircadianDay: Equatable {
    let wakeTime: Date
    let dipTime: Date
    let dayStartHour: Double
    let dayEndHour: Double
    let nowHour: Double
    let hoursUntilDip: Double
    let alertness: [AlertnessPoint]
    let recommendedSleepMinutes: Int
}

enum CircadianEngine {
    /// Post-wake peak then afternoon trough — same two-process shape RISE popularized.
    static func build(
        now: Date = .now,
        wakeTime: Date?,
        sleepNeedMinutes: Int,
        sleepDebtMinutes: Int
    ) -> CircadianDay {
        let cal = Calendar.current
        let resolvedWake = wakeTime ?? defaultWake(on: now, calendar: cal)
        let wakeHour = hourFraction(resolvedWake, calendar: cal)

        // Circadian dip ~7.5h after wake, clamped into early/mid afternoon.
        let rawDip = wakeHour + 7.5
        let dipHour = min(17.5, max(13.0, rawDip))
        let dipTime = date(on: now, hourFraction: dipHour, calendar: cal)

        let nowHour = hourFraction(now, calendar: cal)
        var hoursUntil = dipHour - nowHour
        if hoursUntil < -12 {
            hoursUntil += 24
        }

        let debtDrag = min(0.22, Double(sleepDebtMinutes) / 60.0 * 0.04)
        let alertness = stride(from: 6.0, through: 24.0, by: 0.25).map { h -> AlertnessPoint in
            let circadian = 0.55 + 0.35 * sin((h - (wakeHour + 2.5)) / 24 * 2 * .pi)
            let dip = 0.30 * exp(-pow(h - dipHour, 2) / 2.2)
            let wakeValley = 0.28 * exp(-(h - wakeHour) / 1.15)
            let level = max(0.05, circadian - dip - wakeValley - debtDrag)
            return AlertnessPoint(hour: h, level: level)
        }

        // Recovery target grows with leftover debt (capped).
        let recovery = min(10 * 60, sleepNeedMinutes + min(90, sleepDebtMinutes / 2))

        return CircadianDay(
            wakeTime: resolvedWake,
            dipTime: dipTime,
            dayStartHour: 6,
            dayEndHour: 24,
            nowHour: nowHour,
            hoursUntilDip: hoursUntil,
            alertness: alertness,
            recommendedSleepMinutes: recovery
        )
    }

    static func hourFraction(_ date: Date, calendar: Calendar = .current) -> Double {
        let h = calendar.component(.hour, from: date)
        let m = calendar.component(.minute, from: date)
        let s = calendar.component(.second, from: date)
        return Double(h) + Double(m) / 60 + Double(s) / 3600
    }

    static func date(on day: Date, hourFraction: Double, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: day)
        let hours = Int(hourFraction)
        let minutes = Int((hourFraction - Double(hours)) * 60)
        return calendar.date(byAdding: DateComponents(hour: hours, minute: minutes), to: start) ?? day
    }

    private static func defaultWake(on now: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = 7
        comps.minute = 0
        let morning = calendar.date(from: comps) ?? now
        if now < morning {
            return calendar.date(byAdding: .day, value: -1, to: morning) ?? morning
        }
        return morning
    }
}
