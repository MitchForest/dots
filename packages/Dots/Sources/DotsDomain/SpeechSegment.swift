/// One piece of a live transcription. Volatile segments are the current
/// hypothesis for in-flight audio — each replaces the last; finalized
/// segments are settled text that commits.
public struct SpeechSegment: Equatable, Sendable {
    public var isFinal: Bool
    public var text: String

    public init(text: String, isFinal: Bool) {
        self.isFinal = isFinal
        self.text = text
    }
}

public enum SpeechAvailability: Equatable, Sendable {
    case available
    /// The on-device model needs downloading first.
    case modelNotInstalled
    case permissionDenied
    case unavailable(reason: String)
}
