import Foundation
import HealthKit

/// Reads sleep from Apple Health. Nothing is written back and nothing leaves the device.
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private let sleepType = HKCategoryType(.sleepAnalysis)

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Whether the system permission sheet has yet to be shown. HealthKit never says whether
    /// read access was granted, only whether we may still ask.
    func needsAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let status = try? await store.statusForAuthorizationRequest(toShare: [], read: [sleepType])
        return status == .shouldRequest
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: [sleepType])
    }

    /// Nights from the last `days` days, oldest first.
    func recentNights(days: Int = 10) async throws -> [SleepNight] {
        guard isAvailable else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType,
                                         predicate: HKQuery.predicateForSamples(withStart: start, end: Date()))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)
        return Self.nights(from: samples)
    }

    // MARK: Parsing

    /// Clusters samples into nights (a gap of two hours or more starts a new one), then keeps
    /// one source per night. iPhone and Apple Watch often both log the same night, and
    /// adding them together would double it.
    static func nights(from samples: [HKCategorySample]) -> [SleepNight] {
        var clusters: [[HKCategorySample]] = []
        var clusterEnd = Date.distantPast
        for sample in samples.sorted(by: { $0.startDate < $1.startDate }) {
            if clusters.isEmpty || sample.startDate.timeIntervalSince(clusterEnd) >= 2 * 3600 {
                clusters.append([sample])
                clusterEnd = sample.endDate
            } else {
                clusters[clusters.count - 1].append(sample)
                clusterEnd = max(clusterEnd, sample.endDate)
            }
        }

        return clusters.compactMap { cluster in
            let bySource = Dictionary(grouping: cluster) {
                $0.sourceRevision.source.bundleIdentifier
            }
            let candidates = bySource.values.compactMap(night(from:))
            // Prefer a source with stages, then the one that saw the most sleep.
            return candidates.max {
                ($0.hasStages ? 1 : 0, $0.asleepMinutes) < ($1.hasStages ? 1 : 0, $1.asleepMinutes)
            }
        }
        .filter { $0.asleepMinutes >= 120 }
    }

    private static func night(from samples: [HKCategorySample]) -> SleepNight? {
        var deep = 0.0, rem = 0.0, core = 0.0, unspecified = 0.0, awake = 0.0
        var asleepStart: Date?, asleepEnd: Date?
        var inBed: [HKCategorySample] = []

        for sample in samples {
            let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
            switch value {
            case .inBed:
                inBed.append(sample)
                continue
            case .awake:
                awake += minutes
                continue
            case .asleepDeep: deep += minutes
            case .asleepREM: rem += minutes
            case .asleepCore: core += minutes
            case .asleepUnspecified: unspecified += minutes
            @unknown default: continue
            }
            asleepStart = min(asleepStart ?? sample.startDate, sample.startDate)
            asleepEnd = max(asleepEnd ?? sample.endDate, sample.endDate)
        }

        if let start = asleepStart, let end = asleepEnd {
            return SleepNight(
                start: start, end: end,
                asleepMinutes: Int(deep + rem + core + unspecified),
                deepMinutes: Int(deep), remMinutes: Int(rem), coreMinutes: Int(core),
                awakeMinutes: Int(awake),
                hasStages: deep + rem + core > 0
            )
        }

        // iPhone Sleep Schedule only: time in bed is the best estimate available.
        guard let start = inBed.map(\.startDate).min(),
              let end = inBed.map(\.endDate).max() else { return nil }
        let minutes = inBed.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60 }
        return SleepNight(start: start, end: end, asleepMinutes: Int(minutes),
                          deepMinutes: 0, remMinutes: 0, coreMinutes: 0,
                          awakeMinutes: Int(awake), hasStages: false)
    }
}
