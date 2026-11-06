import Foundation

/// Sleep typed in by the facilitator during a user test, standing in for Apple Health so the
/// app shows the driver's own night. Times are minutes after midnight.
struct TestSleep: Codable, Equatable {
    enum Quality: String, Codable, CaseIterable, Identifiable {
        case good, ok, poor
        var id: String { rawValue }

        /// Share of the night in deep and REM sleep, against the 20% and 25% targets.
        var stages: (deep: Double, rem: Double) {
            switch self {
            case .good: (0.20, 0.25)
            case .ok: (0.14, 0.18)
            case .poor: (0.07, 0.09)
            }
        }
    }

    var isOn = false
    var lastBed = 23 * 60 + 30
    var lastWake = 5 * 60
    var quality: Quality = .ok
    /// Fills the six nights before with the usual pattern, so the week chart and sleep debt
    /// aren't built on one night.
    var fillWeek = true
    var usualBed = 23 * 60
    var usualWake = 5 * 60 + 30

    static func duration(bed: Int, wake: Int) -> Int {
        (wake - bed + 24 * 60) % (24 * 60)
    }

    func nights(now: Date = Date(), calendar: Calendar = .current) -> [SleepNight] {
        var wake = calendar.date(bySettingHour: lastWake / 60, minute: lastWake % 60, second: 0, of: now)!
        if wake > now { wake = calendar.date(byAdding: .day, value: -1, to: wake)! }

        var nights = [night(bed: lastBed, wake: wake, minutesOfWake: lastWake, quality: quality)]
        if fillWeek {
            for daysBack in 1...6 {
                let day = calendar.date(byAdding: .day, value: -daysBack, to: wake)!
                let usual = calendar.date(bySettingHour: usualWake / 60, minute: usualWake % 60,
                                          second: 0, of: day)!
                nights.append(night(bed: usualBed, wake: usual, minutesOfWake: usualWake, quality: .ok))
            }
        }
        return nights.compactMap { $0 }
    }

    private func night(bed: Int, wake: Date, minutesOfWake: Int, quality: Quality) -> SleepNight? {
        let minutes = Self.duration(bed: bed, wake: minutesOfWake)
        guard minutes >= 60 else { return nil }
        let deep = Int(Double(minutes) * quality.stages.deep)
        let rem = Int(Double(minutes) * quality.stages.rem)
        return SleepNight(
            start: wake.addingTimeInterval(-Double(minutes) * 60), end: wake,
            asleepMinutes: minutes, deepMinutes: deep, remMinutes: rem,
            coreMinutes: minutes - deep - rem, awakeMinutes: 0, hasStages: true
        )
    }

    // MARK: Storage

    private static let key = "test.driverSleep"
    private static let momentKey = "test.momentOverride"

    static func load() -> TestSleep {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(TestSleep.self, from: data) else { return TestSleep() }
        return value
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }

    static func loadMoment() -> JourneyState? {
        UserDefaults.standard.string(forKey: momentKey).flatMap(JourneyState.init(rawValue:))
    }

    static func saveMoment(_ state: JourneyState?) {
        UserDefaults.standard.set(state?.rawValue, forKey: momentKey)
    }
}
