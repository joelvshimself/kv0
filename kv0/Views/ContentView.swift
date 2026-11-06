import SwiftUI

private enum PresentedSheet: String, Identifiable {
    case info
    case settings

    var id: String { rawValue }
}

struct ContentView: View {
    @State private var viewModel = DayViewModel()
    @State private var presentedSheet: PresentedSheet?
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .english
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var copy: Copy { language.copy }
    private var snapshot: DaySnapshot { viewModel.snapshot(copy: copy) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                DayLayout(
                    state: viewModel.journeyState,
                    snapshot: snapshot,
                    note: copy.note(for: viewModel.prediction.noteKey),
                    showBreakAction: viewModel.journeyState == .breakDue,
                    onInfo: { presentedSheet = .info },
                    onBreak: { viewModel.markBreakTaken() }
                )
                .padding(.horizontal, Space.margin)
                .padding(.top, 52)
                .padding(.bottom, 16)
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.reink, value: viewModel.journeyState)
                .animation(.easeInOut(duration: 0.3), value: language)
            }
            .scrollIndicators(.hidden)

            GlassIconButton(systemImage: "gearshape", label: copy.settings) {
                presentedSheet = .settings
            }
            .padding(.trailing, Space.margin)
            .padding(.top, 4)
        }
        .safeAreaInset(edge: .bottom) {
            StatePickerBar(selection: Binding(
                get: { viewModel.journeyState },
                set: { viewModel.selectState($0) }
            ))
            .padding(.horizontal, Space.margin)
            .padding(.bottom, 8)
        }
        .background(StarfieldBackground())
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .info:
                InfoSheet(text: snapshot.text)
            case .settings:
                LanguageSheet(language: $language, viewModel: viewModel)
            }
        }
        .environment(\.copy, copy)
        .preferredColorScheme(.dark)
        .task(id: language) {
            viewModel.start(language: language)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.refresh() }
            }
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

struct DayLayout: View {
    let state: JourneyState
    let snapshot: DaySnapshot
    let note: String
    var showBreakAction = false
    let onInfo: () -> Void
    var onBreak: () -> Void = {}
    var revealOnAppear = true

    @Environment(\.copy) private var copy

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

                HStack(spacing: 10) {
                    if !snapshot.text.suggestions.isEmpty {
                        GlassIconButton(systemImage: "info", label: copy.info, action: onInfo)
                            .transition(.scale.combined(with: .opacity))
                    }
                    if showBreakAction {
                        Button(action: onBreak) {
                            Text(copy.takeBreak)
                                .font(Typeface.caption.weight(.medium))
                                .foregroundStyle(Nova.ember)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.white.opacity(0.06)))
                                .overlay(Capsule().strokeBorder(Nova.hairline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                OrbitHero(snapshot: snapshot)
                TimeGraphView(snapshot: snapshot)
            }

            MetricColumnsView(snapshot: snapshot)

            SleepScoreChart(nights: snapshot.nights, note: note)
        }
    }
}

#Preview {
    ContentView()
}
