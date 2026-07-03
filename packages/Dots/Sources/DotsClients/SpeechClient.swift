public import Dependencies
public import DotsDomain
import AVFoundation
import Foundation
import Speech
import Synchronization

/// Boundary to on-device speech: mic capture → `SpeechAnalyzer` →
/// transcription segments. Volatile segments are the live hypothesis (each
/// replaces the last); finalized segments are settled text. Everything runs
/// on this Mac — audio never leaves it.
public struct SpeechClient: Sendable {
    public var availability: @Sendable () async -> SpeechAvailability =
        { .unavailable(reason: "unavailable") }
    public var ensureModel: @Sendable () async throws -> Void =
        { throw SpeechClientError.unavailable }
    public var requestPermission: @Sendable () async -> Bool = { false }
    public var transcribe: @Sendable () -> AsyncThrowingStream<SpeechSegment, any Error> =
        { AsyncThrowingStream { $0.finish(throwing: SpeechClientError.unavailable) } }

    public init() {}
}

enum SpeechClientError: Error, Equatable {
    case audioFormatUnavailable
    case unavailable
}

// MARK: - Live

extension SpeechClient {
    public static func live() -> Self {
        var client = Self()
        client.availability = {
            if AVCaptureDevice.authorizationStatus(for: .audio) == .denied {
                return .permissionDenied
            }
            let locale = Locale.current
            let supported = await SpeechTranscriber.supportedLocales
            guard supported.contains(where: { Self.matches($0, locale) }) else {
                return .unavailable(reason: "Transcription isn't available for your language yet.")
            }
            let installed = await SpeechTranscriber.installedLocales
            guard installed.contains(where: { Self.matches($0, locale) }) else {
                return .modelNotInstalled
            }
            return .available
        }
        client.ensureModel = {
            let transcriber = SpeechTranscriber(locale: Locale.current, preset: .progressiveTranscription)
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        }
        client.requestPermission = {
            await AVCaptureDevice.requestAccess(for: .audio)
        }
        client.transcribe = {
            AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        try await Self.run(continuation: continuation)
                        continuation.finish()
                    } catch is CancellationError {
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        return client
    }

    private static func matches(_ lhs: Locale, _ rhs: Locale) -> Bool {
        lhs.identifier(.bcp47) == rhs.identifier(.bcp47)
            || lhs.language.languageCode == rhs.language.languageCode
    }

    private static func run(
        continuation: AsyncThrowingStream<SpeechSegment, any Error>.Continuation
    ) async throws {
        let transcriber = SpeechTranscriber(locale: Locale.current, preset: .progressiveTranscription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber]
        ) else { throw SpeechClientError.audioFormatUnavailable }

        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        let engine = AVAudioEngine()
        let hardwareFormat = engine.inputNode.outputFormat(forBus: 0)
        // The audio tap runs off-thread; the converter lives behind a lock.
        let converterBox = Mutex<AVAudioConverter?>(nil)

        try engine.inputNode.installAudioTap(
            onBus: 0,
            bufferSize: 4096,
            format: hardwareFormat
        ) { readOnlyBuffer, _ in
            let buffer = AVAudioPCMBuffer(copying: readOnlyBuffer)
            converterBox.withLock { converter in
                if converter == nil {
                    converter = AVAudioConverter(from: hardwareFormat, to: format)
                }
                guard let converter else { return }
                let ratio = format.sampleRate / hardwareFormat.sampleRate
                let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
                guard let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
                    return
                }
                var conversionError: NSError?
                var served = false
                converter.convert(to: converted, error: &conversionError) { _, status in
                    if served {
                        status.pointee = .noDataNow
                        return nil
                    }
                    served = true
                    status.pointee = .haveData
                    return buffer
                }
                if conversionError == nil, converted.frameLength > 0 {
                    inputBuilder.yield(AnalyzerInput(buffer: converted))
                }
            }
        }

        engine.prepare()
        try engine.start()
        defer {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            inputBuilder.finish()
        }

        try await analyzer.start(inputSequence: inputSequence)
        do {
            for try await result in transcriber.results {
                try Task.checkCancellation()
                continuation.yield(
                    SpeechSegment(text: String(result.text.characters), isFinal: result.isFinal)
                )
            }
        } catch {
            await analyzer.cancelAndFinishNow()
            throw error
        }
        await analyzer.cancelAndFinishNow()
    }
}

// MARK: - Mocks & dependency registration

extension SpeechClient {
    // periphery:ignore - test support; SPM test targets sit outside this scan
    /// Scripted fixture: yields the segments, then ends (as if the writer
    /// stopped talking and the stream wound down).
    public static func inMemory(segments: [SpeechSegment] = []) -> Self {
        var client = Self()
        client.availability = { .available }
        client.ensureModel = {}
        client.requestPermission = { true }
        client.transcribe = {
            AsyncThrowingStream { continuation in
                for segment in segments {
                    continuation.yield(segment)
                }
                continuation.finish()
            }
        }
        return client
    }

    /// Fails every call — the default test value so unstubbed access is loud.
    public static var unavailable: Self { Self() }
}

enum SpeechClientKey: DependencyKey {
    static var liveValue: SpeechClient { .live() }
    static var testValue: SpeechClient { .unavailable }
}

extension DependencyValues {
    public var speechClient: SpeechClient {
        get { self[SpeechClientKey.self] }
        set { self[SpeechClientKey.self] = newValue }
    }
}
