import Foundation
import UserNotifications
import UIKit

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    
    private override init() {
        super.init()
    }
    
    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        
        await MainActor.run {
            self.isAuthorized = granted
        }
        
        if granted {
            await registerForRemoteNotifications()
        }
    }
    
    @MainActor
    private func registerForRemoteNotifications() async {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func handleDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        
        Task {
            await DataSyncManager.shared.setDeviceToken(tokenString)
        }
    }
    
    func scheduleLocalWakeUpNotification(at date: Date, sleepScore: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Good morning! ☀️"
        content.body = "Your sleep score: \(sleepScore)/100. \(getSleepScoreMessage(sleepScore))"
        content.sound = .default
        content.badge = 1
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "wake_up_\(date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule wake-up notification: \(error)")
            }
        }
    }
    
    func scheduleLocalPreDipNotification(at date: Date, dipTime: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Energy dip approaching"
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let dipTimeStr = timeFormatter.string(from: dipTime)
        
        content.body = "Your energy dip is predicted at \(dipTimeStr). Consider taking a break soon."
        content.sound = .default
        content.badge = 1
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "pre_dip_\(date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule pre-dip notification: \(error)")
            }
        }
    }
    
    private func getSleepScoreMessage(_ score: Int) -> String {
        if score >= 85 { return "Excellent rest! Ready for a productive day." }
        if score >= 70 { return "Good sleep. You should feel refreshed." }
        if score >= 55 { return "Fair sleep. Consider an earlier bedtime tonight." }
        return "Poor sleep. Prioritize recovery today."
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}
