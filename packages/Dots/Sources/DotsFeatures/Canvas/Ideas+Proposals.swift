public import DotsDomain
import ComposableArchitecture2
import DotsClients
import DotsEngine
import Foundation

// MARK: - Proposal review & selection grammar

extension Ideas {
    public enum Tab: Equatable, Sendable {
        case ideas
        case sources
    }

    public enum FolderSelection: Hashable, Sendable {
        case all
        /// Unfiled — files at the directory root.
        case inbox
        case folder(String)

        /// The folder new things land in under this selection.
        public var target: String? {
            if case .folder(let name) = self {
                return name
            }
            return nil
        }
    }

    /// How a click composes with the existing selection: plain replaces,
    /// ⌘ toggles, ⇧ extends a contiguous range from the last-selected row.
    public enum SelectionModifier: Equatable, Sendable {
        case none
        case range
        case toggle
    }

    /// One verdict on one drafted idea. Accept mints a real idea with
    /// extraction provenance in the source's folder; either way the verdict
    /// persists, and a fully reviewed proposal closes as applied.
    func reviewProposedIdea(
        store: FeatureStore<State, Action>,
        state: inout State,
        proposalId: IdeaProposal.ID,
        ideaId: Int,
        verdict: ProposedIdea.Status
    ) {
        guard let accepted = Self.applyVerdict(
            verdict,
            proposalId: proposalId,
            ideaId: ideaId,
            state: &state
        ) else { return }
        state.pendingSelection.removeAll { $0 == "\(proposalId.rawValue)-\(ideaId)" }
        persistProposals([proposalId], store: store, state: state)
        mintAcceptedDots(accepted, store: store, state: state)
    }

    /// The whole selection reviewed in one gesture. Each touched proposal is
    /// persisted exactly once, after all its verdicts land — parallel writes
    /// to the same file must not race.
    func reviewPendingSelection(
        store: FeatureStore<State, Action>,
        state: inout State,
        verdict: ProposedIdea.Status
    ) {
        let rows = state.visiblePendingIdeas.filter { state.pendingSelection.contains($0.id) }
        guard !rows.isEmpty else { return }
        var touched: [IdeaProposal.ID] = []
        var accepted: [AcceptedIdea] = []
        for row in rows {
            guard let minted = Self.applyVerdict(
                verdict,
                proposalId: row.proposalId,
                ideaId: row.idea.id,
                state: &state
            ) else { continue }
            if !touched.contains(row.proposalId) {
                touched.append(row.proposalId)
            }
            accepted.append(contentsOf: minted)
        }
        state.pendingSelection = []
        persistProposals(touched, store: store, state: state)
        mintAcceptedDots(accepted, store: store, state: state)
    }

    /// An accepted draft ready to become a real idea.
    struct AcceptedIdea {
        var text: String
        var sourceId: Source.ID
    }

    /// Pure state mutation for one verdict; nil when the idea wasn't
    /// pending. Returns what should be minted (empty for discards).
    private static func applyVerdict(
        _ verdict: ProposedIdea.Status,
        proposalId: IdeaProposal.ID,
        ideaId: Int,
        state: inout State
    ) -> [AcceptedIdea]? {
        guard var proposal = state.proposals.first(where: { $0.id == proposalId }),
              let idea = proposal.ideas.first(where: { $0.id == ideaId }),
              idea.status == .pending
        else { return nil }
        proposal.ideas = proposal.ideas.map {
            guard $0.id == ideaId else { return $0 }
            var reviewed = $0
            reviewed.status = verdict
            return reviewed
        }
        if proposal.pendingIdeas.isEmpty {
            proposal.status = .applied
        }
        state.proposals = state.proposals.map { $0.id == proposal.id ? proposal : $0 }
        guard verdict == .accepted else { return [] }
        return [AcceptedIdea(text: idea.text, sourceId: proposal.sourceId)]
    }

    private func persistProposals(
        _ ids: [IdeaProposal.ID],
        store: FeatureStore<State, Action>,
        state: State
    ) {
        let vault = state.vault
        for id in ids {
            guard let proposal = state.proposals.first(where: { $0.id == id }) else { continue }
            store.addTask {
                try await vaultClient.updateProposal(vault, proposal)
            }
        }
    }

    private func mintAcceptedDots(
        _ accepted: [AcceptedIdea],
        store: FeatureStore<State, Action>,
        state: State
    ) {
        let vault = state.vault
        for item in accepted {
            let source = state.sources.first { $0.id == item.sourceId }
            let seed = DotSeed(
                content: item.text,
                source: DotSource(kind: .text, url: source?.url, ref: item.sourceId),
                folder: source?.folder
            )
            store.addTask {
                let dot = try await vaultClient.createDot(vault, seed)
                try store.send(.dotCaptured(dot))
            }
        }
    }

    /// Deletes every selected idea in one gesture; positions and files go
    /// with them, the arrangement persists once.
    func deleteSelection(store: FeatureStore<State, Action>, state: inout State) {
        let ids = state.selection
        guard !ids.isEmpty else { return }
        state.dots.removeAll { ids.contains($0.id) }
        state.freshDotID = nil
        state.selection = []
        for id in ids {
            state.arrangement.positions[id.rawValue] = nil
        }
        let arrangement = state.arrangement
        let vault = state.vault
        store.addTask {
            for id in ids {
                try await vaultClient.deleteDot(vault, id)
            }
            try await vaultClient.writeArrangement(vault, arrangement)
        }
    }

    /// A plain click also opens the reader; composing gestures (⌘, ⇧)
    /// only build the selection.
    func selectSource(_ id: Source.ID, modifier: SelectionModifier, state: inout State) {
        state.sourceSelection = Self.composedSelection(
            tapped: id,
            modifier: modifier,
            current: state.sourceSelection,
            order: state.visibleSources.map(\.id)
        )
        if modifier == .none {
            state.openSourceID = id
        }
    }

    func deleteSource(_ id: Source.ID, store: FeatureStore<State, Action>, state: inout State) {
        state.sources.removeAll { $0.id == id }
        state.sourceSelection.removeAll { $0 == id }
        if state.openSourceID == id {
            state.openSourceID = nil
        }
        let vault = state.vault
        store.addTask {
            try await vaultClient.deleteSource(vault, id)
        }
    }

    /// Deletes every selected source in one gesture; the reader closes if
    /// it was showing one of them. Extracted ideas stay — deleting the
    /// source never deletes your dots.
    func deleteSourceSelection(store: FeatureStore<State, Action>, state: inout State) {
        let ids = state.sourceSelection
        guard !ids.isEmpty else { return }
        state.sources.removeAll { ids.contains($0.id) }
        state.sourceSelection = []
        if let open = state.openSourceID, ids.contains(open) {
            state.openSourceID = nil
        }
        let vault = state.vault
        store.addTask {
            for id in ids {
                try await vaultClient.deleteSource(vault, id)
            }
        }
    }

    /// Finder's selection grammar over an ordered list of row ids.
    public static func composedSelection<ID: Equatable>(
        tapped: ID,
        modifier: SelectionModifier,
        current: [ID],
        order: [ID]
    ) -> [ID] {
        switch modifier {
        case .none:
            return [tapped]
        case .toggle:
            if current.contains(tapped) {
                return current.filter { $0 != tapped }
            }
            return current + [tapped]
        case .range:
            guard let anchor = current.last,
                  let anchorIndex = order.firstIndex(of: anchor),
                  let tappedIndex = order.firstIndex(of: tapped)
            else { return [tapped] }
            let slice = anchorIndex <= tappedIndex
                ? Array(order[anchorIndex...tappedIndex])
                : Array(order[tappedIndex...anchorIndex].reversed())
            return slice
        }
    }
}
