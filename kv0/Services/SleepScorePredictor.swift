import Foundation

/// RISE-style sleep energy score: sleep need vs obtained, debt carry, timing consistency,
/// efficiency, and optional overnight heart-rate calmness.
struct SleepPrediction: Equatable {
    let score: Int
    let sleepNeedMinutes: Int
    let sleepDebtMinutes: Int
    let nights: [NightScore]
    let usedHealth: Bool
    let noteKey: SleepPredictionNote
}

enum SleepPredictionNote: Equatable {
    case learning
    case fromHealth
    case estimated
}

enum SleepScorePredictor {
    /// Baseline need before personalization (~8h), matching common adult midpoints.
    static let defaultNeedMinutes = 8 * 60
    static let maxTrackedDebtMinutes = 16 * 60

    static func predict(
        nights: [NightSleep],
        overnightHeartRateBPM: Double? = nil,
        weekdaySymbols: [String]
    ) -> SleepPrediction {
        guard !nights.isEmpty else {
            return fallback(weekdaySymbols: weekdaySymbols)
        }

        let need = personalizedNeed(from: nights)
        var debt = 0
        var scored: [(Date, Int)] = []

        for night in nights {
            let deficit = max(0, need - night.asleepMinutes)
            let surplus = max(0, night.asleepMinutes - need)
            debt = min(maxTrackedDebtMinutes, max(0, debt + deficit - Int(Double(surplus) * 0.7)))

            let consistency = timingConsistencyPenalty(nights: nights, around: night)
            let efficiencyPenalty = Int((1 - min(1, max(0.55, night.efficiency))) * 40)
            let debtPenalty = min(55, Int(Double(debt) / 60.0 * 11.5))
            var score = 100 - debtPenalty - consistency - efficiencyPenalty

            if let bpm = overnightHeartRateBPM {
                // Calm overnight HR supports recovery; elevated HR softens the score.
                if bpm < 52 { score += 4 }
                else if bpm > 72 { score -= 6 }
            }

            scored.append((night.wakeDay, max(1, min(100, score))))
        }

        let lastSeven = Array(scored.suffix(7))
        let chart: [NightScore] = lastSeven.enumerated().map { index, pair in
            NightScore(index: index, score: pair.1, wakeDay: pair.0)
        }

        let latestDebt = debt
        let latestScore = chart.last?.score ?? 70

        return SleepPrediction(
            score: latestScore,
            sleepNeedMinutes: need,
            sleepDebtMinutes: latestDebt,
            nights: chart.isEmpty ? fallbackNights(weekdaySymbols: weekdaySymbols) : chart,
            usedHealth: true,
            noteKey: nights.count >= 5 ? .fromHealth : .learning
        )
    }

    static func fallback(weekdaySymbols: [String]) -> SleepPrediction {
        SleepPrediction(
            score: 78,
            sleepNeedMinutes: defaultNeedMinutes,
            sleepDebtMinutes: 45,
            nights: fallbackNights(weekdaySymbols: weekdaySymbols),
            usedHealth: false,
            noteKey: .estimated
        )
    }

    private static func personalizedNeed(from nights: [NightSleep]) -> Int {
        let recent = nights.suffix(10).map(\.asleepMinutes)
        guard !recent.isEmpty else { return defaultNeedMinutes }
        let mean = recent.reduce(0, +) / recent.count
        // Bias toward the longer nights (proxy for true need) like debt-based models.
        let high = recent.sorted().suffix(max(1, recent.count / 2)).reduce(0, +)
            / max(1, recent.sorted().suffix(max(1, recent.count / 2)).count)
        let blended = Int(Double(mean) * 0.35 + Double(high) * 0.65)
        return min(10 * 60, max(6 * 60, blended))
    }

    private static func timingConsistencyPenalty(nights: [NightSleep], around night: NightSleep) -> Int {
        let peers = nights.filter {
            abs($0.wakeDay.timeIntervalSince(night.wakeDay)) < 8 * 24 * 3600
        }
        guard peers.count >= 3 else { return 4 }

        let wakeSeconds = peers.map { Calendar.current.component(.hour, from: $0.wakeTime) * 3600
            + Calendar.current.component(.minute, from: $0.wakeTime) * 60 }
        let bedSeconds = peers.map { Calendar.current.component(.hour, from: $0.bedtime) * 3600
            + Calendar.current.component(.minute, from: $0.bedtime) * 60 }

        func stddev(_ values: [Int]) -> Double {
            let mean = Double(values.reduce(0, +)) / Double(values.count)
            let varSum = values.reduce(0.0) { $0 + pow(Double($1) - mean, 2) }
            return sqrt(varSum / Double(values.count))
        }

        let wakeStd = stddev(wakeSeconds) / 60 // minutes
        let bedStd = stddev(bedSeconds) / 60
        let jitter = (wakeStd + bedStd) / 2
        if jitter < 25 { return 0 }
        if jitter < 45 { return 4 }
        if jitter < 75 { return 9 }
        return 15
    }

    private static func fallbackNights(weekdaySymbols: [String]) -> [NightScore] {
        let base = [72, 80, 68, 85, 78, 82, 86]
        let cal = Calendar.current
        return base.enumerated().map { index, score in
            let day = cal.date(byAdding: .day, value: index - (base.count - 1), to: cal.startOfDay(for: .now)) ?? .now
            return NightScore(index: index, score: score, wakeDay: day)
        }
    }
}
