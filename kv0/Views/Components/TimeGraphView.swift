import Charts
import SwiftUI

/// Alertness across the day. The glowing orange point marks the dip.
struct TimeGraphView: View {
    let snapshot: DaySnapshot
    @Environment(\.copy) private var copy

    private var dipLevel: Double {
        Rhythm.alertness.min { abs($0.hour - snapshot.dipHour) < abs($1.hour - snapshot.dipHour) }?.level ?? 0
    }

    var body: some View {
        Chart {
            ForEach(Rhythm.alertness) { point in
                AreaMark(x: .value("Hour", point.hour), y: .value("Alertness", point.level))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(colors: [Nova.orange.opacity(0.35), Nova.orange.opacity(0)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                LineMark(x: .value("Hour", point.hour), y: .value("Alertness", point.level))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Nova.bone.opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }

            RuleMark(x: .value("Now", snapshot.nowHour))
                .foregroundStyle(Nova.muted)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .annotation(position: .top, alignment: .center, spacing: 2) {
                    Text(copy.now)
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.bone.opacity(0.6))
                }

            PointMark(x: .value("Dip", snapshot.dipHour), y: .value("Alertness", dipLevel))
                .symbol {
                    Circle()
                        .fill(Nova.orange)
                        .frame(width: 10, height: 10)
                        .shadow(color: Nova.orange, radius: 8)
                }
                .annotation(position: .bottom, spacing: 6,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                    Text(copy.dip)
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.ember)
                }
        }
        .chartXScale(domain: snapshot.dayStart...snapshot.dayEnd)
        .chartYScale(domain: -0.12...1)
        .chartPlotStyle { $0.padding(.bottom, 22) }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: [6, 9, 12, 15, 18, 21, 24]) { value in
                AxisValueLabel {
                    if let hour = value.as(Double.self) {
                        Text(String(format: "%02.0f", hour.truncatingRemainder(dividingBy: 24)))
                            .font(Typeface.caption)
                            .foregroundStyle(Nova.muted)
                    }
                }
            }
        }
        .frame(height: 140)
        .accessibilityLabel(copy.graphAccessibility)
    }
}
