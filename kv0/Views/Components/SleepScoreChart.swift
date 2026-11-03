import Charts
import SwiftUI

struct SleepScoreChart: View {
    let nights: [NightScore]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("sleep score")
                    .font(Typeface.caption)
                    .foregroundStyle(Ink.inkSoft)
                Spacer()
                Text("last 7 nights")
                    .font(Typeface.caption)
                    .foregroundStyle(Ink.inkSoft.opacity(0.7))
            }

            Chart(nights) { night in
                BarMark(x: .value("Night", night.day), y: .value("Score", night.score), width: .ratio(0.42))
                    .foregroundStyle(color(for: night))
                    .clipShape(Capsule())
                    .annotation(position: .top, spacing: 4) {
                        Text("\(night.score)")
                            .font(Typeface.caption.monospacedDigit())
                            .foregroundStyle(night.id == nights.last?.id ? Ink.sumi : Ink.inkSoft.opacity(0.7))
                    }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(Typeface.caption)
                        .foregroundStyle(Ink.inkSoft)
                }
            }
            .frame(height: 110)

            Text("Based on 7 nights. Readings sharpen as kv0 learns your rhythm.")
                .font(Typeface.caption)
                .foregroundStyle(Ink.inkSoft.opacity(0.8))
        }
    }

    private func color(for night: NightScore) -> Color {
        if night.id == nights.last?.id { return Ink.sumi.opacity(0.85) }
        return night.score >= 80 ? Ink.moss.opacity(0.45) : Ink.inkSoft.opacity(0.25)
    }
}
