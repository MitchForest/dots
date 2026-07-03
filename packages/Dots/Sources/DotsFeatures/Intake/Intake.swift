public import ComposableArchitecture2
public import DotsDomain
public import Foundation
import Dependencies
import DotsClients
import DotsEngine

/// The background intake pipeline: whenever a capture lands (browser host,
/// menu bar, or in-app paste), each source that has no proposal yet is
/// distilled into 3–7 drafted ideas by the selected model, written as a
/// proposal sidecar for review in the ideas list. Headless — composed at
/// Home, no view.
///
/// The pipeline is an action chain (one client call per action — the
/// house TestStore rule) and fails quiet: any broken link simply ends the
/// pass, and the next capture or launch tries again. A dismissed proposal
/// is never regenerated.
@Feature
public struct Intake {
    public struct State: Equatable {
        /// Sources awaiting extraction this pass, head first.
        public var queue: [Source] = []
        public var sources: [Source] = []
        public var vault: URL?

        public init() {}
    }

    public enum Action {
        case captureArrived
        case drafted(ideas: [String])
        case extractionLoaded(isEnabled: Bool)
        case proposalWritten
        case proposalsLoaded([IdeaProposal])
        case providerResolved(ModelProvider)
        case sourcesLoaded([Source])
        case vaultLoaded(URL?)
    }

    /// Every link of the pass shares this id: a capture landing mid-pass
    /// cancels the in-flight link and restarts from the top — the fresh
    /// pass recomputes what's pending, so nothing is lost.
    @StoreTaskID var pass

    @Dependency(\.modelClient) var modelClient
    @Dependency(\.vaultClient) var vaultClient

    public init() {}

    public var body: some Feature {
        Update { state, action in
            switch action {
            case .captureArrived:
                store.addTask(id: pass) {
                    try store.send(.vaultLoaded(await vaultClient.storedVaultLocation()))
                }

            case .drafted(let ideas):
                guard let vault = state.vault, let source = state.queue.first else { break }
                state.queue.removeFirst()
                if ideas.isEmpty {
                    // Model quiet or response unparseable: skip this source,
                    // move on; it stays pending for a later pass.
                    generateNext(store: store, state: state)
                } else {
                    store.addTask(id: pass) {
                        _ = try? await vaultClient.createProposal(vault, source.id, ideas)
                        try store.send(.proposalWritten)
                    }
                }

            case .proposalWritten:
                generateNext(store: store, state: state)

            case .proposalsLoaded(let proposals):
                let proposed = Set(proposals.map(\.sourceId))
                state.queue = state.sources.filter { !proposed.contains($0.id) }
                generateNext(store: store, state: state)

            case .providerResolved(let provider):
                guard let source = state.queue.first else { break }
                let request = ModelRequest(
                    provider: provider,
                    prompt: ExtractionPrompt.prompt(title: source.title, content: source.content),
                    instructions: ExtractionPrompt.instructions,
                    maxTokens: ExtractionPrompt.maxTokens
                )
                store.addTask(id: pass) {
                    var response = ""
                    do {
                        for try await snapshot in modelClient.stream(request) {
                            response = snapshot
                        }
                    } catch {
                        response = ""
                    }
                    try store.send(.drafted(ideas: ExtractionPrompt.parse(response)))
                }

            case .sourcesLoaded(let sources):
                state.sources = sources
                guard let vault = state.vault else { break }
                store.addTask(id: pass) {
                    guard let proposals = try? await vaultClient.listProposals(vault) else { return }
                    try store.send(.proposalsLoaded(proposals))
                }

            case .extractionLoaded(let isEnabled):
                // The one setting this pipeline honors: off means captures
                // stay plain sources; already-written proposals are files
                // and remain reviewable.
                guard isEnabled, let vault = state.vault else { break }
                store.addTask(id: pass) {
                    guard let sources = try? await vaultClient.listSources(vault) else { return }
                    try store.send(.sourcesLoaded(sources))
                }

            case .vaultLoaded(let vault):
                state.vault = vault
                guard let vault else { break }
                store.addTask(id: pass) {
                    try store.send(.extractionLoaded(isEnabled: await vaultClient.readIntakeEnabled(vault)))
                }
            }
        }
        .onMount { _ in
            store.addTask(id: pass) {
                try store.send(.vaultLoaded(await vaultClient.storedVaultLocation()))
            }
            store.addTask {
                for await _ in vaultClient.captureEvents() {
                    try store.send(.captureArrived)
                }
            }
        }
    }

    /// Kicks off generation for the head of the queue (resolving the
    /// provider is the one await); an empty queue ends the pass.
    private func generateNext(store: FeatureStore<State, Action>, state: State) {
        guard !state.queue.isEmpty else { return }
        store.addTask(id: pass) {
            try store.send(.providerResolved(await modelClient.readSelectedProvider()))
        }
    }
}
