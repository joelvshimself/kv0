import SwiftUI

struct MetricColumnsView: View {
    let snapshot: DaySnapshot
    @Environment(\.copy) private var copy

    var body: some View {
        HStack(spacing: 12) {
            metric(label: copy.sleepTime, value: copy.duration(snapshot.sleepMinutes))
            metric(label: copy.journeyDuration, value: copy.duration(snapshot.journeyMinutes))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func metric(label: String, value: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(Typeface.caption)
                    .foregroundStyle(Nova.bone.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(value)
                    .font(Typeface.metric)
                    .tracking(Typeface.tracking(for: 34))
                    .foregroundStyle(Nova.bone)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
