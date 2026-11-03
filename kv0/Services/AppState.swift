import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isLoading = true
    @Published var currentSnapshot: DaySnapshot?
    @Published var recentSleepScores: [NightScore] = []
    @Published var errorMessage: String?
    @Published var lastUpdateTime = Date()
    
    private let dataSyncManager = DataSyncManager.shared
    private let healthKit = HealthKitManager.shared
    
    private init() {}
    
    func initialize() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            await dataSyncManager.initialize()
            await refreshData()
        } catch {
            print("Failed to initialize app: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func refreshData() async {
        do {
            let dashboard = try await dataSyncManager.fetchDashboardData()
            
            if let energyPrediction = dashboard.energy_prediction {
                await updateSnapshot(from: energyPrediction)
            }
            
            if !dashboard.recent_sleep.isEmpty {
                updateRecentSleepScores(from: dashboard.recent_sleep)
            }
            
            lastUpdateTime = Date()
            errorMessage = nil
        } catch {
            print("Failed to refresh data: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func updateSnapshot(from prediction: EnergyPredictionResponse) async {
        let now = Date()
        let wakeTime = ISO8601DateFormatter().date(from: prediction.wake_time) ?? now
        let dipTime = ISO8601DateFormatter().date(from: prediction.dip_time) ?? now
        
        let hoursAwake = now.timeIntervalSince(wakeTime) / 3600
        let hoursToDip = dipTime.timeIntervalSince(now) / 3600
        
        let state = determineJourneyState(hoursAwake: hoursAwake, hoursToDip: hoursToDip)
        
        let sleepHours = Double(prediction.sleep_debt_minutes) / 60
        let sleepTimeText = formatDuration(minutes: prediction.sleep_debt_minutes)
        
        let heroValue: Double
        let heroText: String
        let orbitStyle: OrbitStyle
        
        switch state {
        case .morning:
            heroValue = sleepHours
            heroText = sleepTimeText
            orbitStyle = .rest
        case .working, .breakDue:
            heroValue = max(0, hoursToDip)
            heroText = String(format: "%.1f", max(0, hoursToDip))
            orbitStyle = .energy
        case .finishWork:
            let recoveryHours = 8.0
            heroValue = recoveryHours
            heroText = String(format: "%.0f", recoveryHours)
            orbitStyle = .energy
        }
        
        let nowHour = Double(Calendar.current.component(.hour, from: now)) +
                      Double(Calendar.current.component(.minute, from: now)) / 60.0
        let dipHour = Double(Calendar.current.component(.hour, from: dipTime)) +
                      Double(Calendar.current.component(.minute, from: dipTime)) / 60.0
        
        let snapshot = DaySnapshot(
            text: getCopyForState(state),
            heroValue: heroValue,
            heroText: heroText,
            orbitStyle: orbitStyle,
            sleepMinutes: prediction.sleep_debt_minutes,
            journeyMinutes: 0,
            nowHour: nowHour,
            dipHour: dipHour,
            dayStart: Double(Calendar.current.component(.hour, from: wakeTime)),
            dayEnd: 24,
            alertnessCurve: prediction.alertness_curve.map {
                AlertnessPoint(hour: $0.hour, level: $0.level)
            }
        )
        
        currentSnapshot = snapshot
    }
    
    private func updateRecentSleepScores(from sessions: [SleepSessionResponse]) {
        recentSleepScores = sessions.enumerated().map { index, session in
            let score = session.quality_score ?? 75
            return NightScore(index: index, score: score)
        }
    }
    
    private func determineJourneyState(hoursAwake: Double, hoursToDip: Double) -> JourneyState {
        if hoursAwake < 2 {
            return .morning
        }
        
        let currentHour = Calendar.current.component(.hour, from: Date())
        if currentHour >= 18 {
            return .finishWork
        }
        
        if hoursToDip <= 1.5 && hoursToDip > 0 {
            return .breakDue
        }
        
        return .working
    }
    
    private func getCopyForState(_ state: JourneyState) -> StateCopy {
        Copy.english.state(state)
    }
    
    private func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%dh %02dm", hours, mins)
    }
    
    func manualSync() async {
        await dataSyncManager.syncAllData()
        await refreshData()
    }
}
