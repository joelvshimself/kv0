import Foundation
import UserNotifications

/// The numbers a notification quotes. Real values when Health and motion have them,
/// otherwise the sample day.
struct NotificationValues {
    var sleepMinutes = 7 * 60 + 20
    var score = 82
    var dip = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
    var hoursToDip = 5.5
    var drivenMinutes = 7 * 60 + 40
    var goalHours = 8.5
}

/// Local notifications only. The dip is predicted on the device, so the reminder is
/// scheduled here too; no push server or device token is involved.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    static let enabledKey = "dipReminderEnabled"
    static let leadKey = "dipReminderLeadMinutes"
    static let leadOptions = [15, 30, 45, 60]

    /// Everything kv0 can say. Only `dipReminder` is scheduled for real so far; the rest
    /// are sent on demand from the test panel to try the wording with drivers.
    enum Kind: String, CaseIterable, Identifiable {
        case sleepSummary
        case workStarted
        case dipReminder
        case longDrive
        case finishWork

        var id: String { rawValue }
    }

    @Published private(set) var status: UNAuthorizationStatus = .notDetermined
    @Published private(set) var nextReminder: Date?

    private let center = UNUserNotificationCenter.current()
    private let presenter = ForegroundPresenter()
    private let dipReminderID = "kv0.dip-reminder"

    private init() {
        UserDefaults.standard.register(defaults: [Self.enabledKey: true, Self.leadKey: 30])
        center.delegate = presenter
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }
    var leadMinutes: Int { UserDefaults.standard.integer(forKey: Self.leadKey) }
    var isAllowed: Bool { status == .authorized || status == .provisional }

    func refreshStatus() async {
        status = await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        await refreshStatus()
        return granted
    }

    // MARK: Wording

    func content(for kind: Kind, values: NotificationValues, copy: Copy) -> UNMutableNotificationContent {
        let time = values.dip.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(copy.locale))
        let hours = { (h: Double) in h.formatted(.number.precision(.fractionLength(0...1)).locale(copy.locale)) }

        let content = UNMutableNotificationContent()
        switch kind {
        case .sleepSummary:
            content.title = String(format: copy.notifSleepTitle, copy.duration(values.sleepMinutes))
            content.body = String(format: copy.notifSleepBody, values.score, time)
        case .workStarted:
            content.title = copy.notifWorkTitle
            content.body = String(format: copy.notifWorkBody, hours(values.hoursToDip), time)
        case .dipReminder:
            content.title = copy.reminderTitle
            content.body = String(format: copy.reminderBody, time)
        case .longDrive:
            content.title = copy.notifBreakTitle
            content.body = copy.longDriveSentence
        case .finishWork:
            content.title = copy.notifDoneTitle
            content.body = String(format: copy.notifDoneBody, copy.duration(values.drivenMinutes),
                                  hours(values.goalHours))
        }
        content.sound = .default
        content.threadIdentifier = "kv0"
        return content
    }

    // MARK: Real reminder

    /// Replaces any pending dip reminder with one `leadMinutes` before `dip`, if that moment
    /// is still ahead and reminders are on.
    func scheduleDipReminder(dip: Date?, copy: Copy) async {
        center.removePendingNotificationRequests(withIdentifiers: [dipReminderID])
        nextReminder = nil
        await refreshStatus()

        guard isEnabled, let dip, isAllowed else { return }
        let fireDate = dip.addingTimeInterval(-Double(leadMinutes) * 60)
        guard fireDate > Date() else { return }

        var values = NotificationValues()
        values.dip = dip
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: dipReminderID,
            content: content(for: .dipReminder, values: values, copy: copy),
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
        do {
            try await center.add(request)
            nextReminder = fireDate
        } catch {
            print("Could not schedule dip reminder: \(error)")
        }
    }

    // MARK: Test notifications

    /// When each test notification is due, read back from iOS's pending list.
    @Published private(set) var scheduledTests: [Kind: Date] = [:]

    private func testID(_ kind: Kind) -> String { "kv0.test.\(kind.rawValue)" }

    /// Schedules `kind` for real at `date`, replacing any earlier test of that kind, so it
    /// lands on the lock screen or over another app exactly as it would on the road.
    /// Returns false when `date` has passed or notifications are off.
    @discardableResult
    func scheduleTest(_ kind: Kind, at date: Date, values: NotificationValues, copy: Copy) async -> Bool {
        await refreshStatus()
        if status == .notDetermined { await requestAuthorization() }
        guard isAllowed, date > Date() else { return false }

        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let request = UNNotificationRequest(
            identifier: testID(kind),
            content: content(for: kind, values: values, copy: copy),
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
        do {
            try await center.add(request)
        } catch {
            print("Could not schedule test notification: \(error)")
        }
        await refreshScheduledTests()
        return scheduledTests[kind] != nil
    }

    func cancelTest(_ kind: Kind) async {
        center.removePendingNotificationRequests(withIdentifiers: [testID(kind)])
        await refreshScheduledTests()
    }

    func refreshScheduledTests() async {
        let pending = await center.pendingNotificationRequests()
        var due: [Kind: Date] = [:]
        for kind in Kind.allCases {
            if let request = pending.first(where: { $0.identifier == testID(kind) }),
               let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() {
                due[kind] = date
            }
        }
        scheduledTests = due
    }

    /// Re-words pending test notifications after the driver's sleep or the language changed,
    /// keeping their times.
    func refreshTestContent(values: NotificationValues, copy: Copy) async {
        await refreshScheduledTests()
        for (kind, date) in scheduledTests {
            await scheduleTest(kind, at: date, values: values, copy: copy)
        }
    }
}

/// iOS hides a notification that arrives while its app is on screen unless asked to show it.
private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
