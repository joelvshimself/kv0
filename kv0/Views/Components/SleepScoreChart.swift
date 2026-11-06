import Charts
import SwiftUI

struct SleepScoreChart: View {
    let nights: [NightScore]
    let isSample: Bool
    @Environment(\.copy) private var copy

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(copy.sleepScore)
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.bone.opacity(0.6))
                    Spacer()
                    Text(copy.lastNights)
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.muted)
                }

                // Keyed by the night's date so two Mondays in a sparse week stay separate bars.
                Chart(nights) { night in
                    BarMark(x: .value("Night", key(night)),
                            y: .value("Score", night.score), width: .ratio(0.42))
                        .foregroundStyle(color(for: night))
                        .clipShape(Capsule())
                        .annotation(position: .top, spacing: 4) {
                            Text("\(night.score)")
                                .font(Typeface.caption.monospacedDigit())
                                .foregroundStyle(isLast(night) ? Nova.ember : Nova.bone.opacity(0.5))
                        }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let key = value.as(String.self) {
                                Text(weekday(forKey: key))
                                    .font(Typeface.caption)
                                    .foregroundStyle(Nova.muted)
                            }
                        }
                    }
                }
                .frame(height: 110)

                Text(isSample ? copy.sampleNote : String(format: copy.learningNote, nights.count))
                    .font(Typeface.caption)
                    .foregroundStyle(Nova.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func key(_ night: NightScore) -> String {
        String(Int(night.date.timeIntervalSince1970))
    }

    private func weekday(forKey key: String) -> String {
        guard let seconds = TimeInterval(key) else { return "" }
        return Date(timeIntervalSince1970: seconds)
            .formatted(.dateTime.weekday(.abbreviated).locale(copy.locale))
    }

    private func isLast(_ night: NightScore) -> Bool { night.id == nights.last?.id }

    private func color(for night: NightScore) -> Color {
        if isLast(night) { return Nova.orange }
        return night.score >= 80 ? Nova.bone.opacity(0.35) : Nova.bone.opacity(0.14)
    }
}
