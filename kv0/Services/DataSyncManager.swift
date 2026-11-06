import Foundation
import Combine

@MainActor
class DataSyncManager: ObservableObject {
    static let shared = DataSyncManager()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private let healthKit = HealthKitManager.shared
    private let apiClient = APIClient.shared
    private let userDefaults = UserDefaults.standard
    
    private let userIdKey = "kv0_user_id"
    
    var userId: String {
        get {
            if let existingId = userDefaults.string(forKey: userIdKey) {
                return existingId
            }
            let newId = UUID().uuidString
            userDefaults.set(newId, forKey: userIdKey)
            return newId
        }
        set {
            userDefaults.set(newValue, forKey: userIdKey)
        }
    }
    
    private init() {}
    
    func initialize() async {
        do {
            try await healthKit.requestAuthorization()
            
            let deviceToken = await getDeviceToken()
            let timezone = TimeZone.current.identifier
            
            let userRequest = UserRequest(
                id: userId,
                device_token: deviceToken,
                timezone: timezone,
                wake_time: nil,
                sleep_time: nil,
                pre_dip_notification_minutes: 30,
                notifications_enabled: true
            )
            
            _ = try await apiClient.registerUser(userRequest)
            
            await syncAllData()
        } catch {
            print("Failed to initialize DataSyncManager: \(error)")
            syncError = error
        }
    }
    
    func syncAllData() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            await syncSleepData()
            lastSyncDate = Date()
            syncError = nil
        } catch {
            print("Sync failed: \(error)")
            syncError = error
        }
    }
    
    func syncSleepData() async {
        do {
            guard let lastNightSleep = try await healthKit.fetchLastNightSleep() else {
                print("No sleep data available")
                return
            }
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let sessionRequest = SleepSessionRequest(
                user_id: userId,
                start_time: formatter.string(from: lastNightSleep.startTime),
                end_time: formatter.string(from: lastNightSleep.endTime),
                duration_minutes: lastNightSleep.totalMinutes,
                quality_score: lastNightSleep.overallScore,
                deep_sleep_minutes: lastNightSleep.deepSleepMinutes,
                rem_sleep_minutes: lastNightSleep.remSleepMinutes,
                light_sleep_minutes: lastNightSleep.lightSleepMinutes,
                awake_minutes: lastNightSleep.awakeMinutes,
                source: "HealthKit"
            )
            
            let response = try await apiClient.submitSleep(sessionRequest)
            print("Sleep data synced successfully: \(response)")
        } catch {
            print("Failed to sync sleep data: \(error)")
            throw error
        }
    }
    
    func fetchDashboardData() async throws -> DashboardResponse {
        try await apiClient.getDashboard(userId: userId)
    }
    
    func updateUserSettings(
        preDipNotificationMinutes: Int? = nil,
        notificationsEnabled: Bool? = nil
    ) async throws {
        let deviceToken = await getDeviceToken()
        
        let request = UserRequest(
            id: userId,
            device_token: deviceToken,
            timezone: TimeZone.current.identifier,
            wake_time: nil,
            sleep_time: nil,
            pre_dip_notification_minutes: preDipNotificationMinutes,
            notifications_enabled: notificationsEnabled
        )
        
        _ = try await apiClient.registerUser(request)
    }
    
    private func getDeviceToken() async -> String? {
        return userDefaults.string(forKey: "apns_device_token")
    }
    
    func setDeviceToken(_ token: String) {
        userDefaults.set(token, forKey: "apns_device_token")
    }
}
