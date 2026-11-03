import SwiftUI

struct MetricColumnsView: View {
    let snapshot: DaySnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            metric(label: "sleep time", value: snapshot.sleepMinutes.hoursMinutes)
            Rectangle()
                .fill(Ink.sumi.opacity(0.18))
                .frame(width: 0.8)
                .padding(.horizontal, Space.margin)
            metric(label: "journey duration", value: snapshot.journeyMinutes.hoursMinutes)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typeface.caption)
                .foregroundStyle(Ink.inkSoft)
            Text(value)
                .font(Typeface.metric)
                .foregroundStyle(Ink.sumi)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
