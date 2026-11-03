import SwiftUI

struct ContentView: View {
    @State private var state: JourneyState = .working
    @State private var showingInfo = false
    @State private var showingLanguage = false
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .english
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var copy: Copy { language.copy }
    private var snapshot: DaySnapshot { state.snapshot(copy) }

    var body: some View {
        ScrollView {
            DayLayout(state: state, copy: copy, onInfo: { showingInfo = true })
                .padding(.horizontal, Space.margin)
                .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top) {
            CornerButtons(copy: copy, onSettings: { showingLanguage = true })
            .padding(.horizontal, Space.margin)
            .padding(.top, 4)
        }
        .safeAreaInset(edge: .bottom) {
            StatePickerBar(selection: $state)
                .padding(.horizontal, Space.margin)
                .padding(.bottom, 8)
        }
        .background(StarfieldBackground())
        .sheet(isPresented: $showingInfo) {
            InfoSheet(text: snapshot.text)
        }
        .sheet(isPresented: $showingLanguage) {
            LanguageSheet(language: $language)
        }
        .environment(\.copy, copy)
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.reink, value: state)
        .animation(.easeInOut(duration: 0.3), value: language)
    }
}

struct CornerButtons: View {
    let copy: Copy
    let onSettings: () -> Void

    var body: some View {
        HStack {
            Spacer()
            GlassIconButton(systemImage: "gearshape", label: copy.settings, action: onSettings)
        }
    }
}

struct DayLayout: View {
    let state: JourneyState
    let copy: Copy
    let onInfo: () -> Void
    var revealOnAppear = true

    private var snapshot: DaySnapshot { state.snapshot(copy) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            VStack(alignment: .leading, spacing: 12) {
                RevealText(snapshot.text.sentence, revealOnAppear: revealOnAppear)
                    .font(Typeface.sentence)
                    .tracking(Typeface.tracking(for: 30))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .id("\(state.rawValue)-\(snapshot.text.sentence)")
                    .transition(.opacity)

                if !snapshot.text.suggestions.isEmpty {
                    GlassIconButton(systemImage: "info", label: copy.info, action: onInfo)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                OrbitHero(snapshot: snapshot)
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
