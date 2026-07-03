public import ComposableArchitecture2
public import DotsDomain
public import Foundation
import Dependencies
import DotsClients

/// The ⌘P command palette as its own feature: recents when the query is
/// empty, ranked full-text hits across the whole vault (drafts, ideas,
/// sources) as you type. The editor owns what selection and dismissal mean.
@Feature
public struct QuickOpen {
    public struct State: Equatable {
        public var documents: [VaultDocument] = []
        public var hits: [VaultSearchHit] = []
        public var query = ""
        public var vault: URL

        public var isSearching: Bool {
            !query.trimmingCharacters(in: .whitespaces).isEmpty
        }

        public init(vault: URL) {
            self.vault = vault
        }
    }

    public enum Action {
        case dismissed
        case documentSelected(VaultDocument)
        case documentsLoaded([VaultDocument])
        case hitSelected(VaultSearchHit)
        case hitsLoaded([VaultSearchHit])
    }

    @StoreTaskID var search

    @Dependency(\.continuousClock) var clock
    @Dependency(\.vaultClient) var vaultClient

    public init() {}

    public var body: some Feature {
        Update { state, action in
            switch action {
            case .dismissed, .documentSelected, .hitSelected:
                // The editor intercepts these: it owns closing the palette,
                // switching documents, and revealing ideas/sources.
                break

            case .documentsLoaded(let documents):
                state.documents = documents

            case .hitsLoaded(let hits):
                state.hits = hits
            }
        }
        .onMount { state in
            let vault = state.vault
            store.addTask {
                let documents = try await vaultClient.recentDocuments(vault)
                try store.send(.documentsLoaded(documents))
            }
        }
        .onChange(of: store.query) { state in
            let query = state.query.trimmingCharacters(in: .whitespaces)
            let vault = state.vault
            store.addTask(id: search) {
                guard !query.isEmpty else {
                    try store.send(.hitsLoaded([]))
                    return
                }
                // Debounce: a keystroke mid-word shouldn't scan the vault.
                try await clock.sleep(for: .milliseconds(200))
                guard let hits = try? await vaultClient.searchVault(vault, query) else { return }
                try store.send(.hitsLoaded(hits))
            }
        }
    }
}
