import Foundation

enum JourneyState: String, CaseIterable, Identifiable {
    case morning
    case working
    case breakDue
    case finishWork

    var id: String { rawValue }

    func snapshot(_ copy: Copy) -> DaySnapshot {
        let text = copy.state(self)
        let sleepMinutes = 7 * 60 + 20

        switch self {
        case .morning:
            return DaySnapshot(
                text: text,
                heroValue: Double(sleepMinutes) / 60,
                heroText: copy.duration(sleepMinutes),
                orbitStyle: .rest,
                sleepMinutes: sleepMinutes,
                journeyMinutes: 35,
                nowHour: 7.5,
                dipHour: 15.0,
                dayStart: 6,
                dayEnd: 24
            )
        case .working:
            return DaySnapshot(
                text: text,
                heroValue: 2.5,
                heroText: "2.5",
                orbitStyle: .energy,
                sleepMinutes: sleepMinutes,
                journeyMinutes: 35,
                nowHour: 12.5,
                dipHour: 15.0,
                dayStart: 6,
                dayEnd: 24
            )
        case .breakDue:
            return DaySnapshot(
                text: text,
                heroValue: 2.7,
                heroText: "2.7",
                orbitStyle: .energy,
                sleepMinutes: sleepMinutes,
                journeyMinutes: 35,
                nowHour: 14.3,
                dipHour: 15.0,
                dayStart: 6,
                dayEnd: 24
            )
        case .finishWork:
            return DaySnapshot(
                text: text,
                heroValue: 8,
                heroText: "8",
                orbitStyle: .energy,
                sleepMinutes: sleepMinutes,
                journeyMinutes: 70,
                nowHour: 19.5,
                dipHour: 15.0,
                dayStart: 6,
                dayEnd: 24
            )
        }
    }
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
    var alertnessCurve: [AlertnessPoint]?
    
    init(text: StateCopy, heroValue: Double, heroText: String, orbitStyle: OrbitStyle,
         sleepMinutes: Int, journeyMinutes: Int, nowHour: Double,
         dipHour: Double = 15.0, dayStart: Double = 6, dayEnd: Double = 24,
         alertnessCurve: [AlertnessPoint]? = nil) {
        self.text = text
        self.heroValue = heroValue
        self.heroText = heroText
        self.orbitStyle = orbitStyle
        self.sleepMinutes = sleepMinutes
        self.journeyMinutes = journeyMinutes
        self.nowHour = nowHour
        self.dipHour = dipHour
        self.dayStart = dayStart
        self.dayEnd = dayEnd
        self.alertnessCurve = alertnessCurve
    }
}

struct AlertnessPoint: Identifiable {
    let hour: Double
    let level: Double
    var id: Double { hour }
}

struct NightScore: Identifiable {
    let index: Int
    let score: Int
    var id: Int { index }
}

enum Rhythm {
    /// Two-process style alertness: morning rise, post-lunch dip near 15:00, evening wane.
    static let alertness: [AlertnessPoint] = stride(from: 6.0, through: 24.0, by: 0.25).map { h in
        let circadian = 0.55 + 0.35 * sin((h - 9) / 24 * 2 * .pi)
        let dip = 0.28 * exp(-pow(h - 15, 2) / 2.2)
        let wake = 0.3 * exp(-(h - 6) / 1.2)
        return AlertnessPoint(hour: h, level: max(0.05, circadian - dip - wake))
    }

    /// Oldest first; index lines up with `Copy.weekdays`.
    static let nights: [NightScore] = [72, 80, 68, 85, 78, 82, 86].enumerated().map {
        NightScore(index: $0.offset, score: $0.element)
    }
}
