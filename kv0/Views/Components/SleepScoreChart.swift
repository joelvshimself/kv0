import Charts
import SwiftUI

struct SleepScoreChart: View {
    let nights: [NightScore]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("sleep score")
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.bone.opacity(0.6))
                    Spacer()
                    Text("last 7 nights")
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.muted)
                }

                Chart(nights) { night in
                    BarMark(x: .value("Night", night.day), y: .value("Score", night.score), width: .ratio(0.42))
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
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(Typeface.caption)
                            .foregroundStyle(Nova.muted)
                    }
                }
                .frame(height: 110)

                Text("Based on 7 nights. Readings sharpen as kv0 learns your rhythm.")
                    .font(Typeface.caption)
                    .foregroundStyle(Nova.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func isLast(_ night: NightScore) -> Bool { night.id == nights.last?.id }

    private func color(for night: NightScore) -> Color {
        if isLast(night) { return Nova.orange }
        return night.score >= 80 ? Nova.bone.opacity(0.35) : Nova.bone.opacity(0.14)
    }
}
