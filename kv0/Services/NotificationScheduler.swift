import Foundation
import UserNotifications

enum AppNotificationID {
    static let morningWake = "kv0.morning.wake"
    static let dipLead = "kv0.dip.lead30h"
}

@MainActor
final class NotificationScheduler {
    /// Exact lead the journey asked for: warn 30 hours before the next energy dip.
    static let dipLead: TimeInterval = 30 * 60 * 60

    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func reschedule(
        wakeTime: Date,
        dipTime: Date,
        sleepScore: Int,
        hoursUntilDip: Double,
        language: AppLanguage
    ) async {
        center.removePendingNotificationRequests(
            withIdentifiers: [AppNotificationID.morningWake, AppNotificationID.dipLead]
        )

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let copy = NotificationCopy(language: language)
        let now = Date()

        // Morning: fire at today's wake if still ahead, otherwise tomorrow's wake.
        var morningFire = wakeTime
        if morningFire <= now {
            morningFire = Calendar.current.date(byAdding: .day, value: 1, to: wakeTime) ?? wakeTime.addingTimeInterval(24 * 3600)
        }
        // Prefer a few minutes after wake so Health may have written last night.
        morningFire = morningFire.addingTimeInterval(5 * 60)

        let morningContent = UNMutableNotificationContent()
        morningContent.title = copy.morningTitle
        morningContent.body = copy.morningBody(score: sleepScore, hoursUntilDip: max(0, hoursUntilDip))
        morningContent.sound = .default

        if let morningTrigger = calendarTrigger(for: morningFire) {
            let request = UNNotificationRequest(
                identifier: AppNotificationID.morningWake,
                content: morningContent,
                trigger: morningTrigger
            )
            try? await center.add(request)
        }

        // 30 hours before the upcoming dip (and the one after, so the lead always exists).
        let dips = upcomingDips(from: dipTime, count: 3)
        for (index, dip) in dips.enumerated() {
            let fire = dip.addingTimeInterval(-Self.dipLead)
            guard fire > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = copy.dipTitle
            content.body = copy.dipBody(dipTime: dip)
            content.sound = .default

            if let trigger = calendarTrigger(for: fire) {
                let request = UNNotificationRequest(
                    identifier: "\(AppNotificationID.dipLead).\(index)",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }
        }
    }

    private func upcomingDips(from first: Date, count: Int) -> [Date] {
        (0..<count).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: first)
        }
    }

    private func calendarTrigger(for date: Date) -> UNCalendarNotificationTrigger? {
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    }
}

private struct NotificationCopy {
    let language: AppLanguage

    var morningTitle: String {
        language == .bahasa ? "Pagi, kv0" : "Morning, kv0"
    }

    func morningBody(score: Int, hoursUntilDip: Double) -> String {
        let hours = String(format: "%.1f", hoursUntilDip)
        if language == .bahasa {
            return "Skor tidurmu \(score). Sekitar \(hours) jam menuju penurunan energimu."
        }
        return "Your sleep score is \(score). About \(hours)h until your energy dip."
    }

    var dipTitle: String {
        language == .bahasa ? "30 jam menuju penurunan" : "30 hours until your dip"
    }

    func dipBody(dipTime: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .bahasa ? "id_ID" : "en_US")
        formatter.dateFormat = "EEE HH:mm"
        let when = formatter.string(from: dipTime)
        if language == .bahasa {
            return "Penurunan energimu diperkirakan \(when). Rencanakan istirahat dan tidurmu."
        }
        return "Your energy dip is expected \(when). Plan rest and tonight's sleep around it."
    }
}
