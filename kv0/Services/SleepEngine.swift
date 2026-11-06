import Foundation

/// One night of sleep as read from Apple Health, already de-duplicated to a single source.
struct SleepNight: Identifiable, Equatable {
    let start: Date
    let end: Date
    /// Time actually asleep (core + deep + REM + unspecified). Falls back to time in bed
    /// when the only data is an iPhone Sleep Schedule, which records bed time but no stages.
    let asleepMinutes: Int
    let deepMinutes: Int
    let remMinutes: Int
    let coreMinutes: Int
    let awakeMinutes: Int
    /// True when the source recorded sleep stages (Apple Watch and most trackers).
    let hasStages: Bool

    var id: Date { start }
}

/// Everything the screen needs for today, computed on the device from recent nights.
struct SleepModel {
    /// Oldest first, at most seven.
    let nights: [ScoredNight]
    let lastNight: ScoredNight
    /// When today started. The real wake time when last night is recorded, otherwise
    /// last recorded wake time carried forward to today.
    let wake: Date
    /// Hours since midnight of the wake day. Dip and curve share this continuous scale,
    /// so a dip after midnight reads as 24.5 rather than 0.5.
    let wakeHour: Double
    let dipHour: Double
    let dayEnd: Double
    let sleepDebtMinutes: Int
    let curve: [AlertnessPoint]

    var dipDate: Date { wake.addingTimeInterval((dipHour - wakeHour) * 3600) }

    /// Position of `date` on the same continuous hour scale as `wakeHour`.
    func hour(of date: Date) -> Double {
        wakeHour + date.timeIntervalSince(wake) / 3600
    }

    /// Hours of sleep to aim for tonight: eight, plus a share of the week's debt.
    var tonightGoalHours: Double {
        let goal = min(9.5, 8 + Double(sleepDebtMinutes) / 60 * 0.25)
        return (goal * 2).rounded() / 2
    }
}

struct ScoredNight: Identifiable, Equatable {
    let night: SleepNight
    let score: Int
    var id: Date { night.id }
}

/// Port of the scoring and two-process alertness model that used to live on the server.
enum SleepEngine {
    static let targetMinutes = 8 * 60
    private static let minHealthy = 7 * 60
    private static let maxHealthy = 9 * 60

    static func model(from nights: [SleepNight], now: Date = Date(),
                      calendar: Calendar = .current) -> SleepModel? {
        let sorted = nights.sorted { $0.end < $1.end }
        guard !sorted.isEmpty else { return nil }

        var scored: [ScoredNight] = []
        for (index, night) in sorted.enumerated() {
            let previous = Array(sorted[max(0, index - 7)..<index])
            scored.append(ScoredNight(night: night, score: score(night, previous: previous)))
        }
        let week = Array(scored.suffix(7))
        let last = week[week.count - 1]

        let debt = week.reduce(0) { $0 + max(0, targetMinutes - $1.night.asleepMinutes) }

        let wake = wakeTime(for: last.night, now: now, calendar: calendar)
        let wakeHour = hoursSinceMidnight(wake, calendar: calendar)
        let dipHour = wakeHour + dipOffsetHours(sleepDebtMinutes: debt)
        let dayEnd = max(24, (wakeHour + 17).rounded(.up))

        return SleepModel(
            nights: week,
            lastNight: last,
            wake: wake,
            wakeHour: wakeHour,
            dipHour: dipHour,
            dayEnd: dayEnd,
            sleepDebtMinutes: debt,
            curve: alertnessCurve(wakeHour: wakeHour, dipHour: dipHour, dayEnd: dayEnd,
                                  sleepDebtMinutes: debt)
        )
    }

    // MARK: Score

    /// Duration 40%, stage quality 40%, bedtime consistency 20%.
    static func score(_ night: SleepNight, previous: [SleepNight]) -> Int {
        let total = durationScore(night.asleepMinutes) * 0.4
            + qualityScore(night) * 0.4
            + timingScore(night, previous: previous) * 0.2
        return Int(min(100, max(0, total)).rounded())
    }

    static func durationScore(_ minutes: Int) -> Double {
        if (minHealthy...maxHealthy).contains(minutes) { return 100 }
        if minutes < minHealthy {
            return max(0, 100 - Double(minHealthy - minutes) / 60 * 15)
        }
        return max(0, 100 - Double(minutes - maxHealthy) / 60 * 10)
    }

    /// Deep sleep against a 20% target and REM against 25%. Nights without stage data
    /// get a neutral 75 rather than a penalty.
    static func qualityScore(_ night: SleepNight) -> Double {
        guard night.hasStages, night.asleepMinutes > 0 else { return 75 }
        let asleep = Double(night.asleepMinutes)
        let deep = min(100, Double(night.deepMinutes) / asleep / 0.20 * 100)
        let rem = min(100, Double(night.remMinutes) / asleep / 0.25 * 100)
        return (deep + rem) / 2
    }

    /// How close bedtime was to the average of the previous nights.
    static func timingScore(_ night: SleepNight, previous: [SleepNight],
                            calendar: Calendar = .current) -> Double {
        guard !previous.isEmpty else { return 80 }
        let bedtime = bedtimeHour(night.start, calendar: calendar)
        let average = previous.map { bedtimeHour($0.start, calendar: calendar) }
            .reduce(0, +) / Double(previous.count)
        let variance = abs(bedtime - average)
        switch variance {
        case ...0.5: return 100
        case ...1: return 90
        case ...2: return 75
        default: return max(30, 100 - variance * 15)
        }
    }

    // MARK: Dip and alertness

    /// The afternoon dip lands about 7.5 hours after waking, earlier with sleep debt
    /// (at most 1.5 hours earlier).
    static func dipOffsetHours(sleepDebtMinutes: Int) -> Double {
        7.5 - min(1.5, Double(sleepDebtMinutes) / 60 * 0.15)
    }

    static func alertnessCurve(wakeHour: Double, dipHour: Double, dayEnd: Double,
                               sleepDebtMinutes: Int) -> [AlertnessPoint] {
        let debtFactor = min(1, Double(sleepDebtMinutes) / 180)
        return stride(from: wakeHour, through: dayEnd, by: 0.25).map { hour in
            let awake = hour - wakeHour
            let circadian = 0.55 + 0.35 * sin((hour - (wakeHour + 3)) / 24 * 2 * .pi)
            let dip = 0.28 * exp(-pow(hour - dipHour, 2) / 2.2)
            let inertia = 0.3 * exp(-awake / 1.2)
            let pressure = awake / 16 * 0.2 * (1 + debtFactor)
            let level = min(1, max(0.05, circadian - dip - inertia - pressure))
            return AlertnessPoint(hour: hour, level: level)
        }
    }

    // MARK: Time helpers

    /// Last night's real wake time if it was recent; otherwise the same clock time today,
    /// so the curve still lines up when a night wasn't recorded.
    private static func wakeTime(for night: SleepNight, now: Date, calendar: Calendar) -> Date {
        if now.timeIntervalSince(night.end) < 20 * 3600 { return night.end }
        let parts = calendar.dateComponents([.hour, .minute], from: night.end)
        return calendar.date(bySettingHour: parts.hour ?? 7, minute: parts.minute ?? 0,
                             second: 0, of: now) ?? now
    }

    static func hoursSinceMidnight(_ date: Date, calendar: Calendar = .current) -> Double {
        date.timeIntervalSince(calendar.startOfDay(for: date)) / 3600
    }

    /// Bedtimes measured from noon so 23:30 and 00:30 are an hour apart, not 23.
    private static func bedtimeHour(_ date: Date, calendar: Calendar) -> Double {
        let hour = hoursSinceMidnight(date, calendar: calendar)
        return hour < 12 ? hour + 24 : hour
    }
}
