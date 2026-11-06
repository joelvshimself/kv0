import AVFoundation
import Foundation

/// Reads notifications aloud. Each message is recorded with the system voice for its language
/// and saved in Library/Sounds, the one place iOS looks for custom notification sounds, so it
/// plays when the notification arrives even with kv0 closed or the phone locked.
final class NotificationVoice {
    static let shared = NotificationVoice()

    /// Synthesizers mid-recording, kept alive until their last buffer arrives.
    private var active: [ObjectIdentifier: AVSpeechSynthesizer] = [:]
    private let lock = NSLock()
    private let previewer = AVSpeechSynthesizer()

    private init() {}

    /// The best installed voice for a language ("id-ID", "en-US"), preferring premium and
    /// enhanced voices when someone has downloaded them.
    static func voice(for language: String) -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == language }
            .max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: language)
    }

    private func utterance(_ text: String, language: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(for: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.preUtteranceDelay = 0.3
        return utterance
    }

    /// Speaks `text` now, for hearing a notification before scheduling it.
    func preview(_ text: String, language: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        previewer.stopSpeaking(at: .immediate)
        previewer.speak(utterance(text, language: language))
    }

    /// Records `text` as a notification sound and returns its file name, or nil if no voice
    /// could produce it (the notification then falls back to the default sound). Earlier
    /// recordings for the same `key` are deleted, since their notifications were replaced.
    func record(_ text: String, language: String, key: String) async -> String? {
        let folder = Self.soundsFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        removeRecordings(for: key)

        // A fresh name each time: iOS caches notification sounds by name.
        let name = "\(key)-\(UUID().uuidString.prefix(8)).caf"
        let url = folder.appendingPathComponent(name)

        let synthesizer = AVSpeechSynthesizer()
        let id = ObjectIdentifier(synthesizer)
        lock.withLock { active[id] = synthesizer }
        defer { lock.withLock { active[id] = nil } }

        let succeeded = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let once = Once(continuation)
            var file: AVAudioFile?

            synthesizer.write(utterance(text, language: language)) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                // An empty buffer marks the end; dropping the file closes it for iOS to read.
                guard pcm.frameLength > 0 else {
                    let wrote = file != nil
                    file = nil
                    once.resume(wrote)
                    return
                }
                do {
                    if file == nil {
                        file = try AVAudioFile(
                            forWriting: url,
                            settings: [
                                AVFormatIDKey: kAudioFormatLinearPCM,
                                AVSampleRateKey: pcm.format.sampleRate,
                                AVNumberOfChannelsKey: pcm.format.channelCount,
                                AVLinearPCMBitDepthKey: 16,
                                AVLinearPCMIsFloatKey: false,
                                AVLinearPCMIsBigEndianKey: false,
                            ],
                            commonFormat: pcm.format.commonFormat,
                            interleaved: pcm.format.isInterleaved
                        )
                    }
                    try file?.write(from: pcm)
                } catch {
                    print("Could not record notification voice: \(error)")
                    file = nil
                    once.resume(false)
                }
            }

            // A missing voice can leave the callback silent; don't hold up scheduling.
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) { once.resume(false) }
        }

        if succeeded { return name }
        try? FileManager.default.removeItem(at: url)
        return nil
    }

    private func removeRecordings(for key: String) {
        let folder = Self.soundsFolder
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for file in files where file.hasPrefix("\(key)-") {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(file))
        }
    }

    private static var soundsFolder: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds", isDirectory: true)
    }
}

/// Resumes a continuation at most once, from whichever thread gets there first.
private final class Once: @unchecked Sendable {
    private var continuation: CheckedContinuation<Bool, Never>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<Bool, Never>) { self.continuation = continuation }

    func resume(_ value: Bool) {
        lock.withLock {
            continuation?.resume(returning: value)
            continuation = nil
        }
    }
}
