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
    @Published private(set) var driveDay: DriveDay?
    @Published private(set) var driveStatus: DriveTracker.Status = .notDetermined

    private let health = HealthKitManager.shared
    private let notifications = NotificationManager.shared
    private let drives = DriveTracker()

    private init() {}

    /// First launch asks for Health access once, then reads. Later launches just read.
    func start() async {
        if await health.needsAuthorization() {
            try? await health.requestAuthorization()
        }
        await refresh()
        isLoading = false
        startLiveDriving()

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
        await refreshDrives()
        await rescheduleReminder()
    }

    // MARK: Driving

    /// Re-reads today's driving. The first call shows the Motion & Fitness prompt.
    func refreshDrives() async {
        driveStatus = drives.status
        guard driveStatus == .authorized || driveStatus == .notDetermined else {
            driveDay = nil
            return
        }
        driveDay = await drives.day(since: workdayStart)
        driveStatus = drives.status
    }

    func enableDriving() async {
        await refreshDrives()
        startLiveDriving()
    }

    /// Switches the moment the instant a drive starts or ends while kv0 is open.
    func startLiveDriving() {
        drives.startLive {
            Task { @MainActor in await AppState.shared.refreshDrives() }
        }
    }

    func stopLiveDriving() {
        drives.stopLive()
    }

    /// Drives count from an hour before waking, or from 04:00 when wake time is unknown,
    /// so a late-night shift still belongs to the day it started.
    private var workdayStart: Date {
        let now = Date()
        let calendar = Calendar.current
        var anchor = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: now)!
        if anchor > now { anchor = calendar.date(byAdding: .day, value: -1, to: anchor)! }
        guard let wake = model?.wake else { return anchor }
        return min(wake.addingTimeInterval(-3600), now)
    }

    private var drivingKnown: Bool { driveStatus == .authorized && driveDay != nil }

    func rescheduleReminder() async {
        await notifications.scheduleDipReminder(dip: model?.dipDate, copy: storedLanguage.copy)
    }

    private var storedLanguage: AppLanguage {
        UserDefaults.standard.string(forKey: AppLanguage.storageKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    // MARK: What the screen shows

    var isSample: Bool { model == nil }

    /// Two hours behind the wheel without a ten-minute stop calls for a break.
    static let longDriveMinutes = 120

    /// The moment of the day, chosen automatically. Driving is work: the first drive
    /// starts the workday, and an hour parked in the evening ends it. Without motion
    /// access it falls back to the clock.
    func liveState(now: Date = Date()) -> JourneyState {
        let clock = Calendar.current.component(.hour, from: now)
        let toDip = model.map { $0.dipHour - $0.hour(of: now) }
        let dipClose = toDip.map { $0 > 0 && $0 <= 1.5 } ?? false

        if drivingKnown, let day = driveDay {
            guard day.firstStart != nil else {
                return clock >= 18 || clock < 4 ? .finishWork : .morning
            }
            if !day.isDrivingNow, let end = day.lastEnd,
               now.timeIntervalSince(end) >= 3600, clock >= 17 || clock < 4 {
                return .finishWork
            }
            if day.currentStretchMinutes >= Self.longDriveMinutes || dipClose { return .breakDue }
            return .working
        }

        guard let model else { return .working }
        if model.hour(of: now) - model.wakeHour < 2 { return .morning }
        if clock >= 18 || clock < 4 { return .finishWork }
        if dipClose { return .breakDue }
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
        if state == .breakDue, (driveDay?.currentStretchMinutes ?? 0) >= Self.longDriveMinutes {
            text = text.with(sentence: copy.longDriveSentence)
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
            journeyMinutes: drivingKnown ? driveDay?.minutes : nil,
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
