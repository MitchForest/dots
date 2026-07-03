/// Which brain answers: the free on-device model or a writer-supplied key.
/// One interface either way — providers differ only in where tokens come from.
public enum ModelProvider: String, CaseIterable, Equatable, Sendable {
    case claude
    case onDevice

    public var displayName: String {
        switch self {
        case .claude: "Claude (your API key)"
        case .onDevice: "On-device (private, free)"
        }
    }
}

public enum ModelAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)
}

/// One generation request. The stream that answers it yields cumulative
/// snapshots of the response text (not deltas).
public struct ModelRequest: Equatable, Sendable {
    public var instructions: String?
    /// Hard response cap (tokens); nil = provider default.
    public var maxTokens: Int?
    public var prompt: String
    public var provider: ModelProvider

    public init(
        provider: ModelProvider,
        prompt: String,
        instructions: String? = nil,
        maxTokens: Int? = nil
    ) {
        self.instructions = instructions
        self.maxTokens = maxTokens
        self.prompt = prompt
        self.provider = provider
    }
}
