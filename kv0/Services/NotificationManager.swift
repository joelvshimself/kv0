import Foundation
import UserNotifications

/// Local reminders only. The dip is predicted on the device, so the reminder is scheduled
/// here too; no push server or device token is involved.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    static let enabledKey = "dipReminderEnabled"
    static let leadKey = "dipReminderLeadMinutes"
    static let leadOptions = [15, 30, 45, 60]

    @Published private(set) var status: UNAuthorizationStatus = .notDetermined
    @Published private(set) var nextReminder: Date?

    private let center = UNUserNotificationCenter.current()
    private let dipReminderID = "kv0.dip-reminder"

    private init() {
        UserDefaults.standard.register(defaults: [Self.enabledKey: true, Self.leadKey: 30])
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }
    var leadMinutes: Int { UserDefaults.standard.integer(forKey: Self.leadKey) }

    func refreshStatus() async {
        status = await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        await refreshStatus()
        return granted
    }

    /// Replaces any pending dip reminder with one `leadMinutes` before `dip`, if that moment
    /// is still ahead and reminders are on.
    func scheduleDipReminder(dip: Date?, copy: Copy) async {
        center.removePendingNotificationRequests(withIdentifiers: [dipReminderID])
        nextReminder = nil
        await refreshStatus()

        guard isEnabled, let dip,
              status == .authorized || status == .provisional else { return }
        let fireDate = dip.addingTimeInterval(-Double(leadMinutes) * 60)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = copy.reminderTitle
        content.body = String(format: copy.reminderBody, dip.formatted(date: .omitted, time: .shortened))
        content.sound = .default

        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: dipReminderID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
        do {
            try await center.add(request)
            nextReminder = fireDate
        } catch {
            print("Could not schedule dip reminder: \(error)")
        }
    }
}
