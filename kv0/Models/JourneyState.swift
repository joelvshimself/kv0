import Foundation

enum JourneyState: String, CaseIterable, Identifiable {
    case morning
    case working
    case breakDue
    case home

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: "Morning"
        case .working: "Working"
        case .breakDue: "Break due"
        case .home: "Home"
        }
    }

    var snapshot: DaySnapshot {
        switch self {
        case .morning:
            DaySnapshot(
                sentence: "You slept deeply. Today is a good day to start on the hard thing.",
                heroValue: 86,
                heroFormat: .whole,
                heroLabel: "sleep score, last night",
                suggestions: [],
                sleepMinutes: 7 * 60 + 20,
                journeyMinutes: 35,
                nowHour: 7.5
            )
        case .working:
            DaySnapshot(
                sentence: "Steady and focused. You have a long clear stretch ahead.",
                heroValue: 2.5,
                heroFormat: .decimal,
                heroLabel: "hours until your dip",
                suggestions: [],
                sleepMinutes: 7 * 60 + 20,
                journeyMinutes: 35,
                nowHour: 12.5
            )
        case .breakDue:
            DaySnapshot(
                sentence: "Almost three hours without a pause. Step away for fifteen minutes.",
                heroValue: 2.7,
                heroFormat: .decimal,
                heroLabel: "hours since your last break",
                suggestions: ["Walk outside without your phone", "Drink a glass of water", "Look at something far away"],
                sleepMinutes: 7 * 60 + 20,
                journeyMinutes: 35,
                nowHour: 14.3
            )
        case .home:
            DaySnapshot(
                sentence: "You worked well today. Let the evening be slow.",
                heroValue: 8,
                heroFormat: .whole,
                heroLabel: "hours of sleep to recover tonight",
                suggestions: ["You usually fall asleep around 23:40"],
                sleepMinutes: 7 * 60 + 20,
                journeyMinutes: 70,
                nowHour: 19.5
            )
        }
    }
}

struct DaySnapshot {
    enum HeroFormat { case whole, decimal }

    let sentence: String
    let heroValue: Double
    let heroFormat: HeroFormat
    let heroLabel: String
    let suggestions: [String]
    let sleepMinutes: Int
    /// Time spent driving to and from work today.
    let journeyMinutes: Int
    let nowHour: Double

    let dipHour: Double = 15.0
    let dayStart: Double = 6
    let dayEnd: Double = 24

    var heroText: String {
        switch heroFormat {
        case .whole: String(format: "%.0f", heroValue)
        case .decimal: String(format: "%.1f", heroValue)
        }
    }
}

struct AlertnessPoint: Identifiable {
    let hour: Double
    let level: Double
    var id: Double { hour }
}

struct NightScore: Identifiable {
    let day: String
    let score: Int
    var id: String { day }
}

enum Rhythm {
    /// Two-process style alertness: morning rise, post-lunch dip near 15:00, evening wane.
    static let alertness: [AlertnessPoint] = stride(from: 6.0, through: 24.0, by: 0.25).map { h in
        let circadian = 0.55 + 0.35 * sin((h - 9) / 24 * 2 * .pi)
        let dip = 0.28 * exp(-pow(h - 15, 2) / 2.2)
        let wake = 0.3 * exp(-(h - 6) / 1.2)
        return AlertnessPoint(hour: h, level: max(0.05, circadian - dip - wake))
    }

    static let nights: [NightScore] = [
        NightScore(day: "Wed", score: 72),
        NightScore(day: "Thu", score: 80),
        NightScore(day: "Fri", score: 68),
        NightScore(day: "Sat", score: 85),
        NightScore(day: "Sun", score: 78),
        NightScore(day: "Mon", score: 82),
        NightScore(day: "Tue", score: 86),
    ]
}

extension Int {
    var hoursMinutes: String {
        "\(self / 60)h \(String(format: "%02d", self % 60))m"
    }
}
