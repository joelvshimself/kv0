import SwiftUI

struct MetricColumnsView: View {
    let snapshot: DaySnapshot

    var body: some View {
        HStack(spacing: 12) {
            metric(label: "sleep time", value: snapshot.sleepMinutes.hoursMinutes)
            metric(label: "journey duration", value: snapshot.journeyMinutes.hoursMinutes)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func metric(label: String, value: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(Typeface.caption)
                    .foregroundStyle(Nova.bone.opacity(0.6))
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
