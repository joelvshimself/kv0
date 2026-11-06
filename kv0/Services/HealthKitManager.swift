import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    
    private init() {}
    
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        
        let typesToRead: Set<HKObjectType> = [
            sleepType,
            heartRateType,
            restingHeartRateType
        ]
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        
        await MainActor.run {
            self.isAuthorized = true
        }
    }
    
    func fetchLastNightSleep() async throws -> SleepData? {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        let now = Date()
        let startOfYesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: now))!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfYesterday,
            end: now,
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let sleepData = self.processSleepSamples(sleepSamples)
                continuation.resume(returning: sleepData)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchRecentSleepSessions(days: Int = 7) async throws -> [SleepData] {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let sessions = self.groupSleepSamplesBySession(sleepSamples)
                continuation.resume(returning: sessions)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func processSleepSamples(_ samples: [HKCategorySample]) -> SleepData {
        var deepSleepMinutes = 0
        var remSleepMinutes = 0
        var lightSleepMinutes = 0
        var awakeMinutes = 0
        
        var earliestStart: Date?
        var latestEnd: Date?
        
        for sample in samples {
            let durationMinutes = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
            
            if earliestStart == nil || sample.startDate < earliestStart! {
                earliestStart = sample.startDate
            }
            if latestEnd == nil || sample.endDate > latestEnd! {
                latestEnd = sample.endDate
            }
            
            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                 HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                deepSleepMinutes += durationMinutes
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remSleepMinutes += durationMinutes
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                 HKCategoryValueSleepAnalysis.inBed.rawValue:
                lightSleepMinutes += durationMinutes
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awakeMinutes += durationMinutes
            default:
                break
            }
        }
        
        let startTime = earliestStart ?? Date()
        let endTime = latestEnd ?? Date()
        let totalMinutes = deepSleepMinutes + remSleepMinutes + lightSleepMinutes
        
        return SleepData(
            startTime: startTime,
            endTime: endTime,
            totalMinutes: totalMinutes,
            deepSleepMinutes: deepSleepMinutes,
            remSleepMinutes: remSleepMinutes,
            lightSleepMinutes: lightSleepMinutes,
            awakeMinutes: awakeMinutes
        )
    }
    
    private func groupSleepSamplesBySession(_ samples: [HKCategorySample]) -> [SleepData] {
        guard !samples.isEmpty else { return [] }
        
        let sortedSamples = samples.sorted { $0.startDate < $1.startDate }
        var sessions: [[HKCategorySample]] = []
        var currentSession: [HKCategorySample] = []
        
        for sample in sortedSamples {
            if currentSession.isEmpty {
                currentSession.append(sample)
            } else {
                let lastSample = currentSession.last!
                let timeBetween = sample.startDate.timeIntervalSince(lastSample.endDate)
                
                if timeBetween < 2 * 60 * 60 {
                    currentSession.append(sample)
                } else {
                    sessions.append(currentSession)
                    currentSession = [sample]
                }
            }
        }
        
        if !currentSession.isEmpty {
            sessions.append(currentSession)
        }
        
        return sessions.map { processSleepSamples($0) }
            .filter { $0.totalMinutes >= 180 }
            .suffix(7)
    }
}

struct SleepData: Identifiable, Codable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let totalMinutes: Int
    let deepSleepMinutes: Int
    let remSleepMinutes: Int
    let lightSleepMinutes: Int
    let awakeMinutes: Int
    
    var qualityScore: Int {
        let totalSleep = Double(totalMinutes)
        let deepPercentage = Double(deepSleepMinutes) / totalSleep
        let remPercentage = Double(remSleepMinutes) / totalSleep
        let awakePercentage = Double(awakeMinutes) / totalSleep
        
        var score = 0.0
        score += min(25, (deepPercentage / 0.20) * 25)
        score += min(25, (remPercentage / 0.25) * 25)
        score += max(0, 50 - awakePercentage * 100)
        
        return Int(score)
    }
    
    var durationScore: Int {
        let optimalMinutes = 8 * 60
        let minMinutes = 7 * 60
        let maxMinutes = 9 * 60
        
        if totalMinutes >= minMinutes && totalMinutes <= maxMinutes {
            return 100
        } else if totalMinutes < minMinutes {
            let deficit = minMinutes - totalMinutes
            return max(0, 100 - deficit / 4)
        } else {
            let excess = totalMinutes - maxMinutes
            return max(0, 100 - excess / 6)
        }
    }
    
    var overallScore: Int {
        (qualityScore + durationScore) / 2
    }
}

enum HealthKitError: Error {
    case notAvailable
    case authorizationFailed
    case noData
}
