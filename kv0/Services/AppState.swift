import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    enum HealthStatus: Equatable {
        /// No Health app (iPad, Mac).
        case unavailable
        /// The permission sheet has never been shown.
        case notConnected
        /// Asked, but nothing readable came back: no sleep recorded, or access turned off.
        case noData
        case connected
    }

    @Published private(set) var isLoading = true
    @Published private(set) var isRefreshing = false
    @Published private(set) var model: SleepModel?
    @Published private(set) var healthStatus: HealthStatus = .notConnected
    @Published private(set) var lastUpdated: Date?

    private let health = HealthKitManager.shared
    private let notifications = NotificationManager.shared

    private init() {}

    /// First launch asks for Health access once, then reads. Later launches just read.
    func start() async {
        if await health.needsAuthorization() {
            try? await health.requestAuthorization()
        }
        await refresh()
        isLoading = false

        await notifications.refreshStatus()
        if notifications.isEnabled, notifications.status == .notDetermined {
            await notifications.requestAuthorization()
            await rescheduleReminder()
        }
    }

    func connectHealth() async {
        try? await health.requestAuthorization()
        await refresh()
    }

    func refresh() async {
        guard health.isAvailable else {
            healthStatus = .unavailable
            model = nil
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            model = SleepEngine.model(from: try await health.recentNights())
        } catch {
            print("Could not read sleep from Health: \(error)")
            model = nil
        }
        if model != nil {
            healthStatus = .connected
        } else {
            healthStatus = await health.needsAuthorization() ? .notConnected : .noData
        }
        lastUpdated = Date()
        await rescheduleReminder()
    }

    func rescheduleReminder() async {
        await notifications.scheduleDipReminder(dip: model?.dipDate, copy: storedLanguage.copy)
    }

    private var storedLanguage: AppLanguage {
        UserDefaults.standard.string(forKey: AppLanguage.storageKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    // MARK: What the screen shows

    var isSample: Bool { model == nil }

    /// The moment of the day implied by the clock and today's predicted dip.
    func liveState(now: Date = Date()) -> JourneyState {
        guard let model else { return .working }
        let clock = Calendar.current.component(.hour, from: now)
        let nowHour = model.hour(of: now)
        let toDip = model.dipHour - nowHour

        if nowHour - model.wakeHour < 2 { return .morning }
        if clock >= 18 || clock < 4 { return .finishWork }
        if toDip > 0 && toDip <= 1.5 { return .breakDue }
        return .working
    }

    func snapshot(for state: JourneyState, copy: Copy, now: Date = Date()) -> DaySnapshot {
        guard let model else { return state.snapshot(copy) }

        let sleep = model.lastNight.night.asleepMinutes
        let nowHour = model.hour(of: now)
        let toDip = max(0, model.dipHour - nowHour)

        var text = copy.state(state)
        if state == .morning, model.lastNight.score < 70 {
            text = text.with(sentence: copy.morningLightSentence)
        }

        let heroValue: Double
        let heroText: String
        switch state {
        case .morning:
            heroValue = Double(sleep) / 60
            heroText = copy.duration(sleep)
        case .working, .breakDue:
            heroValue = toDip
            heroText = String(format: "%.1f", toDip)
        case .finishWork:
            heroValue = model.tonightGoalHours
            heroText = String(format: "%g", model.tonightGoalHours)
        }

        return DaySnapshot(
            text: text,
            heroValue: heroValue,
            heroText: heroText,
            orbitStyle: state == .morning ? .rest : .energy,
            sleepMinutes: sleep,
            journeyMinutes: nil,
            nowHour: min(max(nowHour, model.wakeHour), model.dayEnd),
            dipHour: model.dipHour,
            dayStart: model.wakeHour,
            dayEnd: model.dayEnd,
            alertnessCurve: model.curve
        )
    }

    var nightScores: [NightScore] {
        guard let model else { return Rhythm.nights }
        return model.nights.map { NightScore(date: $0.night.end, score: $0.score) }
    }
}
