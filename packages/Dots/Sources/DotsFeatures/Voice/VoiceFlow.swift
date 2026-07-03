public import DotsDomain
import DotsClients
import DotsEngine
import Foundation

/// A voice capture in flight: finalized speech accumulates, the volatile
/// hypothesis trails it, and the whole thing becomes text on stop. Shared by
/// the Ideas mic and the capture panel; the editor's in-document dictation
/// has its own run type but shares the stream below.
public struct VoiceCapture: Equatable, Sendable {
    public var committed = ""
    public var isCleaning = false
    public var volatile = ""

    public init() {}

    /// Folds one transcription segment in: volatile replaces the last
    /// hypothesis, finalized commits with spacing glue.
    public mutating func apply(_ segment: SpeechSegment) {
        if segment.isFinal {
            let glue = segment.text.first?.isWhitespace == true || committed.isEmpty
                ? ""
                : CompletionPrompt.leadingGlue(before: committed)
            committed += glue + segment.text
            volatile = ""
        } else {
            volatile = segment.text
        }
    }
}

/// A user-facing speech failure — the message is meant for the whisper.
struct SpeechFlowError: Error {
    let message: String
}

extension SpeechClient {
    /// The whole preamble in one stream: permission, model download if
    /// needed, then live segments. One copy of this dance, not three.
    func readySegments() -> AsyncThrowingStream<SpeechSegment, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    switch await availability() {
                    case .permissionDenied:
                        guard await requestPermission() else {
                            throw SpeechFlowError(
                                message: "Microphone access denied — enable it in System Settings."
                            )
                        }
                    case .modelNotInstalled:
                        try await ensureModel()
                    case .unavailable(let reason):
                        throw SpeechFlowError(message: reason)
                    case .available:
                        break
                    }
                    for try await segment in transcribe() {
                        continuation.yield(segment)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

enum VoiceFlow {
    /// The whisper-ready description of a speech failure.
    static func describe(_ error: any Error) -> String {
        if let flowError = error as? SpeechFlowError {
            return flowError.message
        }
        return error.localizedDescription
    }

    /// Wispr-grade cleanup, best effort: artifacts out, words untouched;
    /// the raw words come back if the model fails.
    static func cleaned(_ committed: String, modelClient: ModelClient) async -> String {
        let provider = await modelClient.readSelectedProvider()
        let request = ModelRequest(
            provider: provider,
            prompt: AssistPrompt.prompt(
                for: .cleanupDictation,
                selection: committed,
                before: "",
                after: ""
            ),
            instructions: AssistPrompt.instructions(for: .cleanupDictation)
        )
        var cleaned = committed
        do {
            for try await snapshot in modelClient.stream(request) {
                cleaned = snapshot
            }
        } catch {
            cleaned = committed
        }
        return cleaned
    }
}
