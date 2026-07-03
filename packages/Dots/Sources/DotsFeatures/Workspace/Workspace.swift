public import ComposableArchitecture2
public import DotsDomain
public import Foundation
import Dependencies
import DotsClients

/// Posted when the writer leaves the workspace; Home tears it down.
enum WorkspaceClosed: FeatureEventKey {
    typealias Value = Void
}

/// The core view: writing surface on one side, the idea canvas on the other.
@Feature
public struct Workspace {
    public struct State: Equatable {
        public var editor: Editor.State?
        public var ideas: Ideas.State
        public var vault: URL

        public init(vault: URL, documentURL: URL? = nil) {
            self.editor = documentURL.map { Editor.State(vault: vault, documentURL: $0) }
            self.ideas = Ideas.State(vault: vault)
            self.vault = vault
        }
    }

    public enum Action {
        case closeButtonTapped
        case draftSeeded(VaultDocument)
        case editor(Editor.Action)
        case ideas(Ideas.Action)
        case startDraftButtonTapped
    }

    @Dependency(\.vaultClient) var vaultClient

    public init() {}

    public var body: some Feature {
        Update { state, action in
            switch action {
            case .editor, .ideas:
                break

            case .closeButtonTapped:
                store.addTask {
                    try store.post(key: WorkspaceClosed.self, value: ())
                }

            case .draftSeeded(let document):
                state.editor = Editor.State(vault: state.vault, documentURL: document.url)

            case .startDraftButtonTapped:
                let dots = state.ideas.selectedDots
                let vault = state.vault
                guard !dots.isEmpty else { break }
                store.addTask {
                    let document = try await vaultClient.createDraftFromDots(vault, dots)
                    try store.send(.draftSeeded(document))
                }
            }
        }
        Features {
            Scope(\.ideas, action: \.ideas) {
                Ideas()
            }
        }
        .ifLet(\.editor, action: \.editor) {
            Editor()
        }
        .onEvent(EditorClosed.self) { _, state in
            state.editor = nil
        }
        .onEvent(IdeasRevealRequested.self) { hit, state in
            // A ⌘P hit outside the editor: put the ideas pane on it. The
            // all-folders scope guarantees the row is actually visible.
            switch hit {
            case .draft:
                break
            case .idea(let dot, _):
                state.ideas.tab = .ideas
                state.ideas.folderSelection = .all
                state.ideas.selection = [dot.id]
                state.ideas.openSourceID = nil
                state.ideas.pendingSelection = []
            case .source(let source, _):
                state.ideas.tab = .sources
                state.ideas.folderSelection = .all
                state.ideas.openSourceID = source.id
            }
        }
        .onEvent(DraftRequested.self) { dots, state in
            // The send verb routes: with a draft open the ideas attach to
            // it; otherwise they seed a fresh one. References either way.
            if state.editor != nil {
                let ids = dots.map(\.id)
                store.addTask {
                    try store.send(.editor(.ideasAttached(ids)))
                }
            } else {
                let vault = state.vault
                store.addTask {
                    let document = try await vaultClient.createDraftFromDots(vault, dots)
                    try store.send(.draftSeeded(document))
                }
            }
        }
    }
}
