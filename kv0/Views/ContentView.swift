import SwiftUI

struct ContentView: View {
    @State private var showingInfo = false
    @State private var showingSettings = false
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .english
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState

    private var copy: Copy { language.copy }

    var body: some View {
        ScrollView {
            if appState.isLoading {
                ProgressView()
                    .tint(Nova.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 240)
            } else {
                // Re-render each minute so the countdown to the dip and the "now" line move.
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let state = appState.liveState(now: context.date)
                    DayLayout(
                        state: state,
                        snapshot: appState.snapshot(for: state, copy: copy, now: context.date),
                        nights: appState.nightScores,
                        isSample: appState.isSample,
                        onInfo: { showingInfo = true },
                        onConnect: { showingSettings = true }
                    )
                    .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.reink, value: state)
                }
                .padding(.horizontal, Space.margin)
                .padding(.bottom, 16)
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top) {
            CornerButtons(copy: copy, showsStatus: !appState.isLoading,
                          onSettings: { showingSettings = true })
                .padding(.horizontal, Space.margin)
                .padding(.top, 4)
        }
        .background(StarfieldBackground())
        .sheet(isPresented: $showingInfo) {
            InfoSheet(text: appState.snapshot(for: appState.liveState(), copy: copy).text)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(language: $language)
        }
        .environment(\.copy, copy)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.3), value: language)
        .refreshable {
            await appState.refresh()
        }
        .task {
            await appState.start()
        }
        .onChange(of: scenePhase) { _, phase in
            guard !appState.isLoading else { return }
            switch phase {
            case .active:
                appState.startLiveDriving()
                Task { await appState.refresh() }
            case .background:
                appState.stopLiveDriving()
            default:
                break
            }
        }
        .onChange(of: language) { _, _ in
            Task { await appState.rescheduleReminder() }
        }
    }
}

struct CornerButtons: View {
    let copy: Copy
    var showsStatus = true
    let onSettings: () -> Void

    var body: some View {
        HStack {
            if showsStatus {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    MomentPill(now: context.date)
                }
                .transition(.opacity)
            }
            Spacer()
            GlassIconButton(systemImage: "gearshape", label: copy.settings, action: onSettings)
        }
    }
}

/// Which moment kv0 has picked, and a car when it can see you driving.
private struct MomentPill: View {
    let now: Date
    @EnvironmentObject private var appState: AppState
    @Environment(\.copy) private var copy

    var body: some View {
        let state = appState.liveState(now: now)
        let driving = appState.driveDay?.isDrivingNow == true
        HStack(spacing: 10) {
            Circle()
                .fill(Nova.orange)
                .frame(width: 8, height: 8)
                .shadow(color: Nova.orange, radius: 6)
            Text(copy.state(state).title)
                .font(Typeface.body.weight(.medium))
                .foregroundStyle(Nova.bone)
                .contentTransition(.opacity)
            if driving {
                Image(systemName: "car.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Nova.ember)
                    .accessibilityLabel(copy.prefs.drivingNow)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background(
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.5))
                .background(Capsule().fill(Nova.surface.opacity(0.85)))
        )
        .overlay(Capsule().strokeBorder(Nova.hairline, lineWidth: 1))
        .animation(.easeInOut(duration: 0.4), value: state)
        .accessibilityElement(children: .combine)
    }
}

struct DayLayout: View {
    let state: JourneyState
    let snapshot: DaySnapshot
    let nights: [NightScore]
    let isSample: Bool
    let onInfo: () -> Void
    var onConnect: () -> Void = {}
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

                if !snapshot.text.suggestions.isEmpty {
                    GlassIconButton(systemImage: "info", label: copy.info, action: onInfo)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            if isSample {
                SampleBanner(text: copy.sampleBanner, action: onConnect)
            }

            VStack(alignment: .leading, spacing: 16) {
                OrbitHero(snapshot: snapshot)
                TimeGraphView(snapshot: snapshot)
            }

            MetricColumnsView(snapshot: snapshot)

            SleepScoreChart(nights: nights, isSample: isSample)
        }
    }
}

/// Says plainly that the numbers are placeholders, and opens Settings to connect Health.
private struct SampleBanner: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Nova.orange)
                Text(text)
                    .font(Typeface.caption)
                    .foregroundStyle(Nova.bone.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Nova.bone.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Nova.orange.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Nova.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
        .environmentObject(NotificationManager.shared)
}
