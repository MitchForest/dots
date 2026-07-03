public import Dependencies
public import DotsDomain
import ClaudeForFoundationModels
import Foundation
import FoundationModels

/// Boundary to language models — on-device Apple Intelligence by default,
/// BYO Claude via the writer's own key. Both flow through the same
/// FoundationModels `LanguageModelSession`, so features never know which
/// brain answered. Streams yield cumulative response snapshots.
///
/// Every endpoint defaults to the loud `unavailable` behavior; `live()`
/// overrides what it implements. Tests override single closures.
public struct ModelClient: Sendable {
    public var availability: @Sendable (_ provider: ModelProvider) async -> ModelAvailability =
        { _ in .unavailable(reason: "unavailable") }
    public var prewarm: @Sendable (_ provider: ModelProvider) async -> Void = { _ in }
    public var readAPIKey: @Sendable (_ provider: ModelProvider) async -> String? = { _ in nil }
    public var readSelectedProvider: @Sendable () async -> ModelProvider = { .onDevice }
    public var stream: @Sendable (_ request: ModelRequest) -> AsyncThrowingStream<String, any Error> =
        { _ in AsyncThrowingStream { $0.finish(throwing: ModelClientError.unavailable) } }
    public var writeAPIKey: @Sendable (_ provider: ModelProvider, _ key: String?) async throws -> Void =
        { _, _ in throw ModelClientError.unavailable }
    public var writeSelectedProvider: @Sendable (_ provider: ModelProvider) async -> Void = { _ in }

    public init() {}
}

enum ModelClientError: Error, Equatable {
    case missingAPIKey
    case unavailable
}

// MARK: - Live

extension ModelClient {
    public static func live() -> Self {
        var client = Self()
        client.availability = { provider in
            switch provider {
            case .onDevice:
                switch SystemLanguageModel.default.availability {
                case .available:
                    return .available
                case .unavailable(let reason):
                    return .unavailable(reason: Self.describe(reason))
                }
            case .claude:
                return Self.keyStore.read(account: ModelProvider.claude.rawValue) != nil
                    ? .available
                    : .unavailable(reason: "Add your Anthropic API key in Settings.")
            }
        }
        client.prewarm = { provider in
            guard provider == .onDevice,
                  SystemLanguageModel.default.availability == .available
            else { return }
            let session = LanguageModelSession(model: Self.proseModel())
            session.prewarm(promptPrefix: nil)
        }
        client.readAPIKey = { provider in
            Self.keyStore.read(account: provider.rawValue)
        }
        client.readSelectedProvider = {
            UserDefaults.standard.string(forKey: Self.providerDefaultsKey)
                .flatMap(ModelProvider.init(rawValue:)) ?? .onDevice
        }
        client.stream = { request in
            AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        let session = try Self.session(for: request)
                        let options = GenerationOptions(
                            samplingMode: nil,
                            maximumResponseTokens: request.maxTokens
                        )
                        for try await snapshot in session.streamResponse(
                            to: request.prompt,
                            options: options
                        ) {
                            continuation.yield(snapshot.content)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        client.writeAPIKey = { provider, key in
            // Empty means "remove", matching the settings field being cleared.
            let value = key.flatMap { $0.isEmpty ? nil : $0 }
            do {
                try Self.keyStore.write(value, account: provider.rawValue)
            } catch {
                throw ModelClientError.unavailable
            }
        }
        client.writeSelectedProvider = { provider in
            UserDefaults.standard.set(provider.rawValue, forKey: Self.providerDefaultsKey)
        }
        return client
    }

    private static let providerDefaultsKey = "blog.dots.model-provider"

    /// Keychain storage for provider API keys — never UserDefaults, never
    /// files. One account per provider, keyed by its raw value.
    private static let keyStore = KeychainStore(service: "blog.dots.model-keys")

    /// The on-device model tuned for prose: permissive guardrails so the
    /// writer's own text never trips content transformation refusals.
    private static func proseModel() -> SystemLanguageModel {
        SystemLanguageModel(guardrails: .permissiveContentTransformations)
    }

    private static func session(for request: ModelRequest) throws -> LanguageModelSession {
        switch request.provider {
        case .onDevice:
            return LanguageModelSession(model: proseModel(), instructions: request.instructions)
        case .claude:
            guard let key = Self.keyStore.read(account: ModelProvider.claude.rawValue) else {
                throw ModelClientError.missingAPIKey
            }
            let model = ClaudeLanguageModel(name: Self.claudeSonnet5, auth: .apiKey(key))
            return LanguageModelSession(model: model, instructions: request.instructions)
        }
    }

    /// Sonnet 5 isn't a compiled-in constant at package 0.1.2 — capabilities
    /// mirror the upstream definition; replace with `.sonnet5` on the next
    /// package release.
    private static let claudeSonnet5 = ClaudeModel(
        id: "claude-sonnet-5",
        capabilities: .init(
            effortLevels: [.low, .medium, .high, .max],
            adaptiveThinking: true,
            structuredOutput: true,
            imageInput: true
        )
    )

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            "This Mac doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in System Settings."
        case .modelNotReady:
            "The on-device model is still downloading — try again shortly."
        @unknown default:
            "The on-device model is unavailable."
        }
    }
}

// MARK: - Mocks & dependency registration

extension ModelClient {
    // periphery:ignore - test support; SPM test targets sit outside this scan
    /// In-memory fixture for previews and tests: everything available,
    /// responses echo canned text as two cumulative snapshots.
    public static func inMemory(
        selectedProvider: ModelProvider = .onDevice,
        response: String = "A mock response."
    ) -> Self {
        let store = InMemoryModelStore(provider: selectedProvider)
        var client = Self()
        client.availability = { _ in .available }
        client.readAPIKey = { provider in await store.key(for: provider) }
        client.readSelectedProvider = { await store.selectedProvider() }
        client.stream = { _ in
            AsyncThrowingStream { continuation in
                let half = String(response.prefix(response.count / 2))
                continuation.yield(half)
                continuation.yield(response)
                continuation.finish()
            }
        }
        client.writeAPIKey = { provider, key in await store.setKey(key, for: provider) }
        client.writeSelectedProvider = { provider in await store.setSelectedProvider(provider) }
        return client
    }

    /// Fails every call — the default test value so unstubbed access is loud.
    public static var unavailable: Self { Self() }
}

private actor InMemoryModelStore {
    private var keys: [ModelProvider: String] = [:]
    private var provider: ModelProvider

    init(provider: ModelProvider) {
        self.provider = provider
    }

    func key(for provider: ModelProvider) -> String? { keys[provider] }

    func selectedProvider() -> ModelProvider { provider }

    func setKey(_ key: String?, for provider: ModelProvider) {
        keys[provider] = key
    }

    func setSelectedProvider(_ provider: ModelProvider) {
        self.provider = provider
    }
}

enum ModelClientKey: DependencyKey {
    static var liveValue: ModelClient { .live() }
    static var testValue: ModelClient { .unavailable }
}

extension DependencyValues {
    public var modelClient: ModelClient {
        get { self[ModelClientKey.self] }
        set { self[ModelClientKey.self] = newValue }
    }
}
