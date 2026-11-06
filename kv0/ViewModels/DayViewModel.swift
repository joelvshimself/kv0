import Foundation
import Observation

enum JourneyMode: String, Equatable {
    case live
    case manual
}

@MainActor
@Observable
final class DayViewModel {
    private let health = HealthKitService()
    private let notifications = NotificationScheduler()

    var journeyState: JourneyState = .morning
    var mode: JourneyMode = .live
    var healthStatus: HealthAuthStatus = .notDetermined
    var notificationsAllowed = false
    var isLoading = false
    var lastError: String?

    var prediction = SleepScorePredictor.fallback(weekdaySymbols: Copy.english.weekdays)
    var circadian = CircadianEngine.build(
        wakeTime: nil,
        sleepNeedMinutes: SleepScorePredictor.defaultNeedMinutes,
        sleepDebtMinutes: 0
    )
    var lastNight: NightSleep?
    var journeyMinutes: Int = 0
    var hoursSinceBreak: Double = 0
    var lastBreakAt: Date?

    private var tickTask: Task<Void, Never>?
    private var language: AppLanguage = .english

    var isHealthConnected: Bool {
        prediction.usedHealth && (healthStatus == .authorized || health.isAvailable)
    }

    func start(language: AppLanguage) {
        self.language = language
        healthStatus = health.authorizationStatus()
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await self?.tickClock()
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    func updateLanguage(_ language: AppLanguage) {
        self.language = language
        Task { await scheduleNotifications() }
    }

    func selectState(_ state: JourneyState) {
        mode = .manual
        journeyState = state
    }

    func returnToLive() {
        mode = .live
        applyLiveState(now: .now)
    }

    func markBreakTaken() {
        lastBreakAt = .now
        hoursSinceBreak = 0
        if mode == .live { applyLiveState(now: .now) }
    }

    func connectHealth() async {
        isLoading = true
        defer { isLoading = false }
        do {
            healthStatus = try await health.requestAuthorization()
            await refresh()
        } catch {
            lastError = error.localizedDescription
            healthStatus = health.authorizationStatus()
        }
    }

    func enableNotifications() async {
        notificationsAllowed = await notifications.requestAuthorization()
        await scheduleNotifications()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        healthStatus = health.authorizationStatus()
        let notificationStatus = await notifications.authorizationStatus()
        notificationsAllowed = notificationStatus == .authorized || notificationStatus == .provisional

        var nights: [NightSleep] = []
        var hr: Double?

        if health.isAvailable {
            do {
                nights = try await health.fetchNights(limit: 14)
                if let latest = nights.last {
                    hr = try await health.averageHeartRate(from: latest.bedtime, to: latest.wakeTime)
                }
                if healthStatus == .notDetermined, !nights.isEmpty {
                    healthStatus = .authorized
                }
            } catch {
                lastError = error.localizedDescription
            }
        }

        lastNight = nights.last
        prediction = SleepScorePredictor.predict(
            nights: nights,
            overnightHeartRateBPM: hr,
            weekdaySymbols: language.copy.weekdays
        )

        let wake = nights.last?.wakeTime
        circadian = CircadianEngine.build(
            wakeTime: wake,
            sleepNeedMinutes: prediction.sleepNeedMinutes,
            sleepDebtMinutes: prediction.sleepDebtMinutes
        )

        if lastBreakAt == nil {
            lastBreakAt = wake ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)
        }
        recomputeBreakHours(now: .now)
        estimateJourneyMinutes()

        if mode == .live {
            applyLiveState(now: .now)
        }

        await scheduleNotifications()
    }

    func snapshot(copy: Copy) -> DaySnapshot {
        let text = liveCopy(base: copy.state(journeyState), copy: copy)
        let sleepMinutes = lastNight?.asleepMinutes ?? prediction.sleepNeedMinutes - min(90, prediction.sleepDebtMinutes)

        switch journeyState {
        case .morning:
            return DaySnapshot(
                text: text,
                heroValue: Double(sleepMinutes) / 60,
                heroText: copy.duration(sleepMinutes),
                orbitStyle: .rest,
                sleepMinutes: sleepMinutes,
                journeyMinutes: journeyMinutes,
                nowHour: circadian.nowHour,
                dipHour: CircadianEngine.hourFraction(circadian.dipTime),
                dayStart: circadian.dayStartHour,
                dayEnd: circadian.dayEndHour,
                alertness: circadian.alertness,
                nights: prediction.nights
            )
        case .working:
            let hours = max(0, circadian.hoursUntilDip)
            return DaySnapshot(
                text: text,
                heroValue: hours,
                heroText: String(format: "%.1f", hours),
                orbitStyle: .energy,
                sleepMinutes: sleepMinutes,
                journeyMinutes: journeyMinutes,
                nowHour: circadian.nowHour,
                dipHour: CircadianEngine.hourFraction(circadian.dipTime),
                dayStart: circadian.dayStartHour,
                dayEnd: circadian.dayEndHour,
                alertness: circadian.alertness,
                nights: prediction.nights
            )
        case .breakDue:
            return DaySnapshot(
                text: text,
                heroValue: hoursSinceBreak,
                heroText: String(format: "%.1f", hoursSinceBreak),
                orbitStyle: .energy,
                sleepMinutes: sleepMinutes,
                journeyMinutes: journeyMinutes,
                nowHour: circadian.nowHour,
                dipHour: CircadianEngine.hourFraction(circadian.dipTime),
                dayStart: circadian.dayStartHour,
                dayEnd: circadian.dayEndHour,
                alertness: circadian.alertness,
                nights: prediction.nights
            )
        case .finishWork:
            let recoveryHours = Double(circadian.recommendedSleepMinutes) / 60
            return DaySnapshot(
                text: text,
                heroValue: recoveryHours,
                heroText: String(format: "%.0f", recoveryHours.rounded()),
                orbitStyle: .energy,
                sleepMinutes: sleepMinutes,
                journeyMinutes: max(journeyMinutes, journeyMinutes == 0 ? 40 : journeyMinutes),
                nowHour: circadian.nowHour,
                dipHour: CircadianEngine.hourFraction(circadian.dipTime),
                dayStart: circadian.dayStartHour,
                dayEnd: circadian.dayEndHour,
                alertness: circadian.alertness,
                nights: prediction.nights
            )
        }
    }

    private func tickClock() async {
        circadian = CircadianEngine.build(
            wakeTime: circadian.wakeTime,
            sleepNeedMinutes: prediction.sleepNeedMinutes,
            sleepDebtMinutes: prediction.sleepDebtMinutes
        )
        recomputeBreakHours(now: .now)
        if mode == .live {
            applyLiveState(now: .now)
        }
    }

    private func recomputeBreakHours(now: Date) {
        let anchor = lastBreakAt ?? circadian.wakeTime
        hoursSinceBreak = max(0, now.timeIntervalSince(anchor) / 3600)
    }

    private func applyLiveState(now: Date) {
        let minutesSinceWake = now.timeIntervalSince(circadian.wakeTime) / 60
        let hour = circadian.nowHour

        if minutesSinceWake < 0 {
            journeyState = .finishWork
            return
        }
        if minutesSinceWake <= 90 {
            journeyState = .morning
            return
        }
        if hour >= 18.5 || circadian.hoursUntilDip < -1.5 {
            journeyState = .finishWork
            return
        }
        if hoursSinceBreak >= 2.7 {
            journeyState = .breakDue
            return
        }
        journeyState = .working
    }

    private func estimateJourneyMinutes() {
        // Without Core Motion / Maps, approximate a commute from wake→work gap.
        // Prefer a stored value once the user logs one; default to a light commute.
        if journeyMinutes == 0 {
            journeyMinutes = 35
        }
    }

    private func liveCopy(base: StateCopy, copy: Copy) -> StateCopy {
        let score = prediction.score
        switch journeyState {
        case .morning:
            let sentence: String
            if language == .bahasa {
                sentence = score >= 80
                    ? "Tidurmu pulih dengan baik (skor \(score)). Hari ini saat yang tepat untuk memulai hal yang sulit."
                    : "Skor tidurmu \(score). Mulai pelan, simpan tenaga sebelum penurunan siang."
            } else {
                sentence = score >= 80
                    ? "You slept well (score \(score)). Today is a good day to start on the hard thing."
                    : "Sleep score \(score). Ease in — save focus for before your afternoon dip."
            }
            return StateCopy(
                title: base.title,
                sentence: sentence,
                heroLabel: base.heroLabel,
                suggestionsTitle: base.suggestionsTitle,
                suggestions: base.suggestions
            )
        case .working:
            let hours = String(format: "%.1f", max(0, circadian.hoursUntilDip))
            let sentence: String
            if language == .bahasa {
                sentence = "Tenang dan fokus. Masih ada \(hours) jam menuju penurunan energimu."
            } else {
                sentence = "Steady and focused. You have \(hours) clear hours until your dip."
            }
            return StateCopy(
                title: base.title,
                sentence: sentence,
                heroLabel: base.heroLabel,
                suggestionsTitle: base.suggestionsTitle,
                suggestions: base.suggestions
            )
        case .breakDue:
            let hours = String(format: "%.1f", hoursSinceBreak)
            let sentence: String
            if language == .bahasa {
                sentence = "Sudah \(hours) jam tanpa jeda. Menjauhlah sejenak selama lima belas menit."
            } else {
                sentence = "\(hours) hours without a pause. Step away for fifteen minutes."
            }
            return StateCopy(
                title: base.title,
                sentence: sentence,
                heroLabel: base.heroLabel,
                suggestionsTitle: base.suggestionsTitle,
                suggestions: base.suggestions
            )
        case .finishWork:
            let need = String(format: "%.0f", Double(circadian.recommendedSleepMinutes) / 60)
            let sentence: String
            if language == .bahasa {
                sentence = "Kerja bagus hari ini. Target tidurmu sekitar \(need) jam untuk menutup utang tidur."
            } else {
                sentence = "You worked well today. Aim for about \(need)h of sleep to close your debt."
            }
            return StateCopy(
                title: base.title,
                sentence: sentence,
                heroLabel: base.heroLabel,
                suggestionsTitle: base.suggestionsTitle,
                suggestions: base.suggestions
            )
        }
    }

    private func scheduleNotifications() async {
        await notifications.reschedule(
            wakeTime: circadian.wakeTime,
            dipTime: circadian.dipTime,
            sleepScore: prediction.score,
            hoursUntilDip: circadian.hoursUntilDip,
            language: language
        )
    }
}
