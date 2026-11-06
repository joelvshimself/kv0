import CoreMotion
import Foundation

/// Today's driving, from the iPhone's motion coprocessor. iOS keeps a week of activity
/// history whether or not kv0 is running, so drives are known even if the app was closed.
struct DriveDay: Equatable {
    /// Drives since the workday window opened, oldest first, with short stops merged in.
    let drives: [DateInterval]
    let isDrivingNow: Bool
    /// Length of the current unbroken stretch of driving, counting stops under ten
    /// minutes as part of it. Zero when not driving.
    let currentStretchMinutes: Int

    var firstStart: Date? { drives.first?.start }
    var lastEnd: Date? { drives.last?.end }
    var minutes: Int { Int(drives.reduce(0) { $0 + $1.duration } / 60) }

    static let empty = DriveDay(drives: [], isDrivingNow: false, currentStretchMinutes: 0)
}

/// One change in detected activity. A stand-in for `CMMotionActivity`, which can't be
/// built outside CoreMotion.
struct ActivitySample {
    let start: Date
    let isDriving: Bool
}

enum DriveDetector {
    /// Gaps shorter than this between driving segments are traffic lights and queues.
    static let mergeGap: TimeInterval = 5 * 60
    /// Drives shorter than this are discarded as misreads.
    static let minimumDrive: TimeInterval = 3 * 60
    /// A stop must be at least this long to count as a break.
    static let breakGap: TimeInterval = 10 * 60

    static func day(from samples: [ActivitySample], now: Date) -> DriveDay {
        let sorted = samples.sorted { $0.start < $1.start }

        // Each sample lasts until the next one starts; the latest lasts until now.
        var segments: [DateInterval] = []
        for (index, sample) in sorted.enumerated() where sample.isDriving {
            let end = index + 1 < sorted.count ? sorted[index + 1].start : now
            if end > sample.start { segments.append(DateInterval(start: sample.start, end: end)) }
        }

        let drives = merge(segments, within: mergeGap).filter { $0.duration >= minimumDrive }
        let isDrivingNow = sorted.last?.isDriving == true

        var stretch: TimeInterval = 0
        if isDrivingNow, let current = merge(segments, within: breakGap).last {
            stretch = now.timeIntervalSince(current.start)
        }

        return DriveDay(drives: drives, isDrivingNow: isDrivingNow,
                        currentStretchMinutes: Int(stretch / 60))
    }

    private static func merge(_ segments: [DateInterval], within gap: TimeInterval) -> [DateInterval] {
        var merged: [DateInterval] = []
        for segment in segments {
            if let last = merged.last, segment.start.timeIntervalSince(last.end) < gap {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, segment.end))
            } else {
                merged.append(segment)
            }
        }
        return merged
    }
}

/// Wraps `CMMotionActivityManager`: history queries plus live updates while kv0 is open.
final class DriveTracker {
    enum Status: Equatable {
        case unavailable
        case notDetermined
        case denied
        case authorized
    }

    private let manager = CMMotionActivityManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private var lastDriving: Bool?

    var status: Status {
        guard CMMotionActivityManager.isActivityAvailable() else { return .unavailable }
        switch CMMotionActivityManager.authorizationStatus() {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    /// Driving since `start`. The first call shows the Motion & Fitness permission prompt.
    func day(since start: Date) async -> DriveDay? {
        guard status != .unavailable else { return nil }
        let now = Date()
        let activities: [CMMotionActivity]? = await withCheckedContinuation { continuation in
            manager.queryActivityStarting(from: start, to: now, to: queue) { activities, error in
                if let error { print("Motion history unavailable: \(error)") }
                continuation.resume(returning: activities)
            }
        }
        guard let activities else { return nil }
        let samples = activities.map {
            ActivitySample(start: $0.startDate, isDriving: $0.automotive && $0.confidence != .low)
        }
        return DriveDetector.day(from: samples, now: now)
    }

    /// Calls `onChange` whenever driving starts or stops while the app is open.
    func startLive(onChange: @escaping @Sendable () -> Void) {
        guard status == .authorized else { return }
        lastDriving = nil
        manager.startActivityUpdates(to: queue) { [weak self] activity in
            guard let self, let activity else { return }
            let driving = activity.automotive && activity.confidence != .low
            if driving != self.lastDriving {
                self.lastDriving = driving
                onChange()
            }
        }
    }

    func stopLive() {
        manager.stopActivityUpdates()
    }
}
