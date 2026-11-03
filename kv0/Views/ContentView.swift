import SwiftUI

struct ContentView: View {
    @State private var state: JourneyState = .working
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var snapshot: DaySnapshot { state.snapshot }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                Text(snapshot.sentence)
                    .font(Typeface.sentence)
                    .foregroundStyle(Ink.sumi)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(state)
                    .transition(.opacity)

                VStack(alignment: .leading, spacing: 20) {
                    DipHeroView(snapshot: snapshot)
                    if !snapshot.suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(snapshot.suggestions, id: \.self) { line in
                                Text(line)
                                    .font(Typeface.body)
                                    .foregroundStyle(Ink.inkSoft)
                            }
                        }
                        .transition(.opacity)
                    }
                    TimeGraphView(snapshot: snapshot)
                }

                BrushRule()

                MetricColumnsView(snapshot: snapshot)

                SleepScoreChart(nights: Rhythm.nights)
            }
            .padding(.horizontal, Space.margin)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            StatePickerBar(selection: $state)
                .padding(.horizontal, Space.margin)
                .padding(.bottom, 8)
        }
        .background(WashiBackground())
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.reink, value: state)
    }
}

#Preview {
    ContentView()
}
