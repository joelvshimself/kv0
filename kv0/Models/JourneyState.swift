import Foundation

enum JourneyState: String, CaseIterable, Identifiable {
    case morning
    case working
    case breakDue
    case finishWork

    var id: String { rawValue }
}

enum OrbitStyle {
    /// Working hours: full-size orbits, even dashes.
    case energy
    /// Morning, after sleep: slightly drawn-in orbits with sparser dashes.
    case rest
}

struct DaySnapshot {
    let text: StateCopy
    let heroValue: Double
    let heroText: String
    let orbitStyle: OrbitStyle
    let sleepMinutes: Int
    /// Time spent driving to and from work today.
    let journeyMinutes: Int
    let nowHour: Double
    let dipHour: Double
    let dayStart: Double
    let dayEnd: Double
    let alertness: [AlertnessPoint]
    let nights: [NightScore]
}

struct AlertnessPoint: Identifiable, Equatable {
    let hour: Double
    let level: Double
    var id: Double { hour }
}

struct NightScore: Identifiable, Equatable {
    let index: Int
    let score: Int
    var wakeDay: Date = .now
    var id: Int { index }
}

enum Rhythm {
    /// Default two-process curve used before live circadian data is ready.
    static let alertness: [AlertnessPoint] = CircadianEngine.build(
        wakeTime: nil,
        sleepNeedMinutes: SleepScorePredictor.defaultNeedMinutes,
        sleepDebtMinutes: 0
    ).alertness
}
