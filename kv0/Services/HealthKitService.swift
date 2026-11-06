import Foundation
import HealthKit

struct SleepSample: Equatable {
    let start: Date
    let end: Date
    let stage: HKCategoryValueSleepAnalysis?

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

struct NightSleep: Identifiable, Equatable {
    /// Calendar day this night "belongs" to (the morning of wake).
    let wakeDay: Date
    let bedtime: Date
    let wakeTime: Date
    let asleepMinutes: Int
    let inBedMinutes: Int
    let samples: [SleepSample]

    var id: Date { wakeDay }

    var efficiency: Double {
        guard inBedMinutes > 0 else { return 0 }
        return Double(asleepMinutes) / Double(inBedMinutes)
    }
}

enum HealthAuthStatus: Equatable {
    case unavailable
    case notDetermined
    case denied
    case authorized
}

@MainActor
final class HealthKitService {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var sleepType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    }

    private var heartRateType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .heartRate)
    }

    func authorizationStatus() -> HealthAuthStatus {
        guard isAvailable, let sleepType else { return .unavailable }
        switch store.authorizationStatus(for: sleepType) {
        case .notDetermined: return .notDetermined
        case .sharingDenied: return .denied
        case .sharingAuthorized: return .authorized
        @unknown default: return .notDetermined
        }
    }

    /// HealthKit read status is opaque after grant; treat a successful query as connected.
    func requestAuthorization() async throws -> HealthAuthStatus {
        guard isAvailable else { return .unavailable }
        var read: Set<HKObjectType> = []
        if let sleepType { read.insert(sleepType) }
        if let heartRateType { read.insert(heartRateType) }
        guard !read.isEmpty else { return .unavailable }

        try await store.requestAuthorization(toShare: [], read: read)
        return authorizationStatus()
    }

    func fetchNights(limit: Int = 14, endingAt end: Date = .now) async throws -> [NightSleep] {
        guard let sleepType else { return [] }

        let start = Calendar.current.date(byAdding: .day, value: -(limit + 2), to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        return Self.groupIntoNights(samples, calendar: .current)
            .sorted { $0.wakeDay < $1.wakeDay }
            .suffix(limit)
            .map { $0 }
    }

    func averageHeartRate(from start: Date, to end: Date) async throws -> Double? {
        guard let heartRateType else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let bpm = stats?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                cont.resume(returning: bpm)
            }
            store.execute(query)
        }
    }

    static func groupIntoNights(_ samples: [HKCategorySample], calendar: Calendar) -> [NightSleep] {
        let mapped: [SleepSample] = samples.compactMap { sample in
            let stage = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            return SleepSample(start: sample.startDate, end: sample.endDate, stage: stage)
        }

        // Cluster by wake morning: any sleep overlapping a night window ending at wake.
        var buckets: [Date: [SleepSample]] = [:]
        for sample in mapped {
            let wakeDay = calendar.startOfDay(for: sample.end)
            buckets[wakeDay, default: []].append(sample)
        }

        return buckets.compactMap { wakeDay, nightSamples in
            let sorted = nightSamples.sorted { $0.start < $1.start }
            guard let bedtime = sorted.first?.start, let wake = sorted.last?.end else { return nil }

            let asleep = sorted.filter { sample in
                guard let stage = sample.stage else { return true }
                switch stage {
                case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
                    return true
                case .inBed, .awake:
                    return false
                @unknown default:
                    return sample.duration > 0
                }
            }
            let asleepMinutes = Int(asleep.reduce(0) { $0 + $1.duration } / 60)
            let inBedMinutes = max(asleepMinutes, Int(wake.timeIntervalSince(bedtime) / 60))
            guard asleepMinutes > 30 else { return nil }

            return NightSleep(
                wakeDay: wakeDay,
                bedtime: bedtime,
                wakeTime: wake,
                asleepMinutes: asleepMinutes,
                inBedMinutes: inBedMinutes,
                samples: sorted
            )
        }
    }
}
