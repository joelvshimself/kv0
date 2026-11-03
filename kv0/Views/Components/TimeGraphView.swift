import Charts
import SwiftUI

/// Alertness across the day as an ink wash. The vermilion seal marks the dip.
struct TimeGraphView: View {
    let snapshot: DaySnapshot

    private var dipLevel: Double {
        Rhythm.alertness.min { abs($0.hour - snapshot.dipHour) < abs($1.hour - snapshot.dipHour) }?.level ?? 0
    }

    var body: some View {
        Chart {
            ForEach(Rhythm.alertness) { point in
                AreaMark(x: .value("Hour", point.hour), y: .value("Alertness", point.level))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(colors: [Ink.sumi.opacity(0.22), Ink.sumi.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                LineMark(x: .value("Hour", point.hour), y: .value("Alertness", point.level))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Ink.sumi.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }

            RuleMark(x: .value("Now", snapshot.nowHour))
                .foregroundStyle(Ink.inkSoft.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                .annotation(position: .top, alignment: .center, spacing: 2) {
                    Text("now")
                        .font(Typeface.caption)
                        .foregroundStyle(Ink.inkSoft)
                }

            PointMark(x: .value("Dip", snapshot.dipHour), y: .value("Alertness", dipLevel))
                .symbol {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Ink.shu)
                        .frame(width: 11, height: 11)
                        .rotationEffect(.degrees(-4))
                }
                .annotation(position: .bottom, spacing: 4) {
                    Text("dip")
                        .font(Typeface.caption)
                        .foregroundStyle(Ink.shu)
                }
        }
        .chartXScale(domain: snapshot.dayStart...snapshot.dayEnd)
        .chartYScale(domain: 0...1)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: [6, 9, 12, 15, 18, 21, 24]) { value in
                AxisValueLabel {
                    if let hour = value.as(Double.self) {
                        Text(String(format: "%02.0f", hour.truncatingRemainder(dividingBy: 24)))
                            .font(Typeface.caption)
                            .foregroundStyle(Ink.inkSoft)
                    }
                }
            }
        }
        .frame(height: 120)
        .accessibilityLabel("Alertness through the day, with a dip at 15:00")
    }
}
