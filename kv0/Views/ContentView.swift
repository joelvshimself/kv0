import SwiftUI

struct ContentView: View {
    @State private var state: JourneyState = .working
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            DayLayout(state: state)
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
        .background(StarfieldBackground())
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.reink, value: state)
    }
}

struct DayLayout: View {
    let state: JourneyState
    var revealOnAppear = true

    private var snapshot: DaySnapshot { state.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            RevealText(snapshot.sentence, revealOnAppear: revealOnAppear)
                .font(Typeface.sentence)
                .tracking(Typeface.tracking(for: 30))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .id(state)
                .transition(.opacity)

            VStack(alignment: .leading, spacing: 16) {
                OrbitHero(snapshot: snapshot)
                if !snapshot.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(snapshot.suggestions, id: \.self) { line in
                            HStack(spacing: 10) {
                                Circle().fill(Nova.orange).frame(width: 5, height: 5)
                                Text(line)
                                    .font(Typeface.body)
                                    .foregroundStyle(Nova.bone.opacity(0.8))
                            }
                        }
                    }
                    .transition(.opacity)
                }
                TimeGraphView(snapshot: snapshot)
            }

            MetricColumnsView(snapshot: snapshot)

            SleepScoreChart(nights: Rhythm.nights)
        }
    }
}

#Preview {
    ContentView()
}
