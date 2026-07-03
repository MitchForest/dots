public import ComposableArchitecture2
public import DotsDomain
import Dependencies
import DotsClients
import Foundation

/// The AI provider pane: pick the brain, see whether it's ready, and hold
/// your own key. The only settings surface Dots has — everything else is
/// opinionated.
@Feature
public struct ModelSettings {
    public struct State: Equatable {
        public var availabilityByProvider: [ModelProvider: ModelAvailability] = [:]
        public var hasStoredKey = false
        public var keyDraft = ""
        public var provider: ModelProvider = .onDevice

        public var selectedAvailability: ModelAvailability? {
            availabilityByProvider[provider]
        }

        public init() {}
    }

    public enum Action {
        case availabilityLoaded(ModelProvider, ModelAvailability)
        case keyCleared
        case keySaved
        case keyStateLoaded(hasKey: Bool)
        case providerLoaded(ModelProvider)
        case providerSelected(ModelProvider)
    }

    @Dependency(\.modelClient) var modelClient

    public init() {}

    public var body: some Feature {
        Update { state, action in
            switch action {
            case .availabilityLoaded(let provider, let availability):
                state.availabilityByProvider[provider] = availability

            case .keyCleared:
                state.hasStoredKey = false
                state.keyDraft = ""
                store.addTask {
                    try await modelClient.writeAPIKey(.claude, nil)
                    let availability = await modelClient.availability(.claude)
                    try store.send(.availabilityLoaded(.claude, availability))
                }

            case .keySaved:
                let key = state.keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { break }
                state.hasStoredKey = true
                state.keyDraft = ""
                store.addTask {
                    try await modelClient.writeAPIKey(.claude, key)
                    let availability = await modelClient.availability(.claude)
                    try store.send(.availabilityLoaded(.claude, availability))
                }

            case .keyStateLoaded(let hasKey):
                state.hasStoredKey = hasKey

            case .providerLoaded(let provider):
                state.provider = provider

            case .providerSelected(let provider):
                state.provider = provider
                store.addTask {
                    await modelClient.writeSelectedProvider(provider)
                    await modelClient.prewarm(provider)
                }
            }
        }
        .onMount { _ in
            store.addTask {
                let provider = await modelClient.readSelectedProvider()
                try store.send(.providerLoaded(provider))
                let key = await modelClient.readAPIKey(.claude)
                try store.send(.keyStateLoaded(hasKey: key != nil))
                for provider in ModelProvider.allCases {
                    let availability = await modelClient.availability(provider)
                    try store.send(.availabilityLoaded(provider, availability))
                }
            }
        }
    }
}
