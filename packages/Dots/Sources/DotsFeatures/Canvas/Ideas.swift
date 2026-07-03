public import ComposableArchitecture2
public import DotsDomain
public import DotsEngine
public import DotsUI
public import Foundation
import Dependencies
import DotsClients

/// Posted when the writer asks for a draft seeded from ideas; the workspace
/// creates it and opens the editor.
enum DraftRequested: FeatureEventKey {
    typealias Value = [Dot]
}

/// The idea workspace: folders · Sources/Ideas list · detail. The canvas is
/// one way of *viewing* the reference graph, not the home of the data.
@Feature
public struct Ideas {
    public struct State: Equatable {
        public var arrangement = CanvasArrangement()
        public var captureError: String?
        public var dots: [Dot] = []
        public var folderSelection: FolderSelection = .all
        public var folders: [String] = []
        /// Selected pending drafted ideas (row ids from `PendingIdea`); the
        /// last one drives the detail pane. Mutually exclusive with the dot
        /// selection.
        public var pendingSelection: [String] = []
        /// Set when an idea is created so the UI opens it straight into editing.
        public var freshDotID: Dot.ID?
        /// Ideas tab presentation: the calm list, or the spatial canvas.
        public var isCanvasView = false
        public var isCapturingSource = false
        public var isLocked = false
        public var openSourceID: Source.ID?
        public var proposals: [IdeaProposal] = []
        public var selection: [Dot.ID] = []
        public var sourceSelection: [Source.ID] = []
        public var sources: [Source] = []
        public var tab: Tab = .ideas
        public var vault: URL
        public var viewport = CanvasViewportState()
        public var voice: VoiceCapture?
        /// Where a running dictation will land, pinned at record start so
        /// clicking around mid-recording can't redirect the words.
        public var voiceTargetID: Dot.ID?

        /// The idea shown in the detail pane — the most recent selection.
        public init(vault: URL) {
            self.vault = vault
        }
    }

    public enum Action {
        case arrangementLoaded(CanvasArrangement)
        case canvasDoubleClicked(CGPoint)
        case connectSelectionTapped
        case createFolderSubmitted(String)
        case deleteDotTapped(Dot.ID)
        case deleteSelectionTapped
        case deleteSourceSelectionTapped
        case deleteSourceTapped(Source.ID)
        case disconnectSelectionTapped
        case distillSubmitted(Source, content: String, tags: [String])
        case dotCaptured(Dot)
        case dotCreated(Dot, CGPoint)
        case dotEdited(Dot.ID, content: String, tags: [String])
        case dotDragEnded(Dot.ID, CGPoint)
        case dotMoved(Dot.ID, folder: String?)
        case dotTapped(Dot.ID, modifier: SelectionModifier)
        case dotsConnected(Dot.ID, Dot.ID)
        case dotsLoaded([Dot])
        case draftFromSelectionTapped
        case extractSelectionTapped(Source, excerpt: String)
        case foldersLoaded([String])
        case makeMineTapped(Dot.ID)
        case newDotButtonTapped
        case pendingIdeaTapped(String, modifier: SelectionModifier)
        case pendingSelectionAccepted
        case pendingSelectionDiscarded
        case proposalsLoaded([IdeaProposal])
        case proposedIdeaAccepted(IdeaProposal.ID, Int)
        case proposedIdeaDiscarded(IdeaProposal.ID, Int)
        case referenceRemoved(Dot.ID, Reference)
        case sourceCaptureFailed(String)
        case sourceCaptured(Source)
        case sourceMoved(Source.ID, folder: String?)
        case sourceTapped(Source.ID, modifier: SelectionModifier)
        case sourceTextSubmitted(title: String, text: String)
        case sourceURLSubmitted(String)
        case sourcesLoaded([Source])
        case synthesizeSelectionTapped
        case voiceCaptureEnded
        case voiceCaptureFailed(String)
        case voiceCaptureToggled
        case voiceCleaned(String)
        case voiceSegment(SpeechSegment)
    }

    @StoreTaskID var voiceStream

    @Dependency(\.modelClient) var modelClient
    @Dependency(\.pageClient) var pageClient
    @Dependency(\.speechClient) var speechClient
    @Dependency(\.vaultClient) var vaultClient

    public init() {}

    public var body: some Feature {
        Update { state, action in
            switch action {
            case .arrangementLoaded(let arrangement):
                state.arrangement = arrangement
                let vault = state.vault
                store.addTask {
                    let sources = try await vaultClient.listSources(vault)
                    try store.send(.sourcesLoaded(sources))
                }

            case .canvasDoubleClicked(let point):
                createDot(store: store, state: state, at: point)

            case .connectSelectionTapped:
                connectSelection(store: store, state: &state)

            case .createFolderSubmitted(let name):
                let cleaned = name.trimmingCharacters(in: .whitespaces)
                guard !cleaned.isEmpty, !cleaned.contains("/"),
                      !state.folders.contains(cleaned)
                else { break }
                state.folders.append(cleaned)
                state.folders.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                state.folderSelection = .folder(cleaned)
                let vault = state.vault
                store.addTask {
                    try await vaultClient.createFolder(vault, cleaned)
                }

            case .deleteDotTapped(let id):
                state.dots.removeAll { $0.id == id }
                state.freshDotID = nil
                state.selection.removeAll { $0 == id }
                state.arrangement.positions[id.rawValue] = nil
                let arrangement = state.arrangement
                let vault = state.vault
                store.addTask {
                    try await vaultClient.deleteDot(vault, id)
                    try await vaultClient.writeArrangement(vault, arrangement)
                }

            case .deleteSelectionTapped:
                deleteSelection(store: store, state: &state)

            case .deleteSourceTapped(let id):
                deleteSource(id, store: store, state: &state)

            case .deleteSourceSelectionTapped:
                deleteSourceSelection(store: store, state: &state)

            case .disconnectSelectionTapped:
                disconnectSelection(store: store, state: &state)

            case .distillSubmitted(let source, let content, let tags):
                createCapturedDot(
                    store: store,
                    vault: state.vault,
                    seed: DotSeed(
                        content: content,
                        references: [Reference(source.id)],
                        tags: tags,
                        folder: source.folder
                    )
                )

            case .dotCaptured(let dot):
                // Captured, not placed: the idea joins the pool unpinned and
                // takes an auto-layout slot — the reader stays open.
                state.dots.insert(dot, at: 0)

            case .dotCreated(let dot, let point):
                state.dots.insert(dot, at: 0)
                state.arrangement.positions[dot.id.rawValue] = CanvasArrangement.Position(
                    x: point.x,
                    y: point.y
                )
                state.freshDotID = dot.id
                state.selection = [dot.id]
                persistArrangement(store: store, state: state)

            case .dotEdited(let id, let content, let tags):
                guard var dot = state.dots.first(where: { $0.id == id }) else { break }
                dot.content = content
                dot.tags = tags
                state.dots = state.dots.map { $0.id == id ? dot : $0 }
                state.freshDotID = nil
                persistDot(store: store, vault: state.vault, dot: dot)

            case .dotDragEnded(let id, let point):
                state.arrangement.positions[id.rawValue] = CanvasArrangement.Position(
                    x: point.x,
                    y: point.y
                )
                persistArrangement(store: store, state: state)

            case .dotMoved(let id, let folder):
                guard var dot = state.dots.first(where: { $0.id == id }) else { break }
                dot.folder = folder
                state.dots = state.dots.map { $0.id == id ? dot : $0 }
                let vault = state.vault
                store.addTask {
                    try await vaultClient.moveDot(vault, id, folder)
                }

            case .dotTapped(let id, let modifier):
                state.pendingSelection = []
                state.freshDotID = nil
                state.selection = Self.composedSelection(
                    tapped: id,
                    modifier: modifier,
                    current: state.selection,
                    order: state.visibleDots.map(\.id)
                )

            case .dotsConnected(let from, let to):
                guard from != to,
                      var anchor = state.dots.first(where: { $0.id == from }),
                      !anchor.references.contains(Reference(to)),
                      state.dots.contains(where: { $0.id == to })
                else { break }
                anchor.references.append(Reference(to))
                state.dots = state.dots.map { $0.id == from ? anchor : $0 }
                persistDot(store: store, vault: state.vault, dot: anchor)

            case .dotsLoaded(let dots):
                state.dots = dots
                let vault = state.vault
                store.addTask {
                    let arrangement = try await vaultClient.readArrangement(vault)
                    try store.send(.arrangementLoaded(arrangement))
                }

            case .draftFromSelectionTapped:
                let dots = state.selectedDots
                guard !dots.isEmpty else { break }
                store.addTask {
                    try store.post(key: DraftRequested.self, value: dots)
                }

            case .extractSelectionTapped(let source, let excerpt):
                let trimmed = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { break }
                createCapturedDot(
                    store: store,
                    vault: state.vault,
                    seed: DotSeed(
                        content: trimmed,
                        source: DotSource(kind: .quote, url: source.url, ref: source.id),
                        folder: source.folder
                    )
                )

            case .foldersLoaded(let folders):
                state.folders = folders
                let vault = state.vault
                store.addTask {
                    let proposals = try await vaultClient.listProposals(vault)
                    try store.send(.proposalsLoaded(proposals))
                }

            case .makeMineTapped(let id):
                guard var dot = state.dots.first(where: { $0.id == id }),
                      let source = dot.source
                else { break }
                // The one deliberate provenance gesture: the words are now
                // the writer's; the source stays as inspiration.
                dot.source = nil
                if let ref = source.ref, !dot.references.contains(Reference(ref)) {
                    dot.references.append(Reference(ref))
                }
                state.dots = state.dots.map { $0.id == id ? dot : $0 }
                persistDot(store: store, vault: state.vault, dot: dot)

            case .newDotButtonTapped:
                let center = state.viewport.canvasPoint(
                    fromViewportPoint: CGPoint(x: 320, y: 240)
                )
                createDot(store: store, state: state, at: center)

            case .pendingIdeaTapped(let id, let modifier):
                state.selection = []
                state.pendingSelection = Self.composedSelection(
                    tapped: id,
                    modifier: modifier,
                    current: state.pendingSelection,
                    order: state.visiblePendingIdeas.map(\.id)
                )

            case .pendingSelectionAccepted:
                reviewPendingSelection(store: store, state: &state, verdict: .accepted)

            case .pendingSelectionDiscarded:
                reviewPendingSelection(store: store, state: &state, verdict: .discarded)

            case .proposalsLoaded(let proposals):
                state.proposals = proposals

            case .proposedIdeaAccepted(let proposalId, let ideaId):
                reviewProposedIdea(
                    store: store,
                    state: &state,
                    proposalId: proposalId,
                    ideaId: ideaId,
                    verdict: .accepted
                )

            case .proposedIdeaDiscarded(let proposalId, let ideaId):
                reviewProposedIdea(
                    store: store,
                    state: &state,
                    proposalId: proposalId,
                    ideaId: ideaId,
                    verdict: .discarded
                )

            case .referenceRemoved(let id, let reference):
                guard var dot = state.dots.first(where: { $0.id == id }) else { break }
                dot.references.removeAll { $0 == reference }
                state.dots = state.dots.map { $0.id == id ? dot : $0 }
                persistDot(store: store, vault: state.vault, dot: dot)

            case .sourceCaptureFailed(let message):
                state.captureError = message
                state.isCapturingSource = false

            case .sourceCaptured(let source):
                state.captureError = nil
                state.isCapturingSource = false
                state.sources.insert(source, at: 0)
                // Straight into the reader: capture flows into extraction.
                state.tab = .sources
                state.openSourceID = source.id

            case .sourceMoved(let id, let folder):
                guard var source = state.sources.first(where: { $0.id == id }) else { break }
                source.folder = folder
                state.sources = state.sources.map { $0.id == id ? source : $0 }
                let vault = state.vault
                store.addTask {
                    try await vaultClient.moveSource(vault, id, folder)
                }

            case .sourceTapped(let id, let modifier):
                selectSource(id, modifier: modifier, state: &state)

            case .sourceTextSubmitted(let title, let text):
                capturePastedSource(store: store, state: &state, title: title, text: text)

            case .sourceURLSubmitted(let raw):
                captureSource(store: store, state: &state, rawURL: raw)

            case .sourcesLoaded(let sources):
                state.sources = sources
                let vault = state.vault
                store.addTask {
                    let folders = try await vaultClient.listFolders(vault)
                    try store.send(.foldersLoaded(folders))
                }

            case .synthesizeSelectionTapped:
                synthesizeSelection(store: store, state: &state)

            case .voiceCaptureEnded:
                finishVoiceCapture(store: store, state: &state, cancelStream: false)

            case .voiceCaptureFailed(let message):
                state.captureError = message
                state.voice = nil
                state.voiceTargetID = nil
                store.addTask {
                    voiceStream.cancel()
                }

            case .voiceCaptureToggled:
                if state.voice != nil {
                    finishVoiceCapture(store: store, state: &state, cancelStream: true)
                } else {
                    startVoiceCapture(store: store, state: &state)
                }

            case .voiceCleaned(let text):
                state.voice = nil
                let targetID = state.voiceTargetID
                state.voiceTargetID = nil
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { break }
                if let targetID, var target = state.dots.first(where: { $0.id == targetID }) {
                    // The words land in the idea that was open when the
                    // recording started, as a fresh paragraph.
                    target.content = target.content.isEmpty
                        ? trimmed
                        : target.content + "\n\n" + trimmed
                    state.dots = state.dots.map { $0.id == target.id ? target : $0 }
                    persistDot(store: store, vault: state.vault, dot: target)
                } else {
                    createCapturedDot(
                        store: store,
                        vault: state.vault,
                        seed: DotSeed(content: trimmed, folder: state.folderSelection.target)
                    )
                }

            case .voiceSegment(let segment):
                applyVoiceSegment(segment, state: &state)
            }
        }
        .onMount { state in
            // Action-by-action chain (dots → arrangement → sources →
            // folders): deterministic under TestStore's receive.
            let vault = state.vault
            store.addTask {
                let dots = try await vaultClient.listDots(vault)
                try store.send(.dotsLoaded(dots))
            }
            // Browser captures land from outside this process; re-run the
            // load chain when the host says something arrived.
            store.addTask {
                for await _ in vaultClient.captureEvents() {
                    let dots = try await vaultClient.listDots(vault)
                    try store.send(.dotsLoaded(dots))
                }
            }
            // Extraction finishes on its own clock (and possibly in another
            // process); refresh the review rows when proposals change.
            store.addTask {
                for await _ in vaultClient.proposalEvents() {
                    let proposals = try await vaultClient.listProposals(vault)
                    try store.send(.proposalsLoaded(proposals))
                }
            }
        }
    }
}

// MARK: - Capture & synthesis

extension Ideas {
    private func createDot(store: FeatureStore<State, Action>, state: State, at point: CGPoint) {
        let vault = state.vault
        let seed = DotSeed(content: "New idea", folder: state.folderSelection.target)
        store.addTask {
            let dot = try await vaultClient.createDot(vault, seed)
            try store.send(.dotCreated(dot, point))
        }
    }

    private func persistArrangement(store: FeatureStore<State, Action>, state: State) {
        let arrangement = state.arrangement
        let vault = state.vault
        store.addTask {
            try await vaultClient.writeArrangement(vault, arrangement)
        }
    }

    private func persistDot(store: FeatureStore<State, Action>, vault: URL, dot: Dot) {
        store.addTask {
            try await vaultClient.updateDot(vault, dot)
        }
    }

    private func capturePastedSource(
        store: FeatureStore<State, Action>,
        state: inout State,
        title: String,
        text: String
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state.captureError = "Nothing to save — paste the text first."
            return
        }
        state.captureError = nil
        state.isCapturingSource = true
        let vault = state.vault
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        let seed = SourceSeed(
            title: cleanTitle.isEmpty ? "Untitled" : cleanTitle,
            content: trimmed,
            folder: state.folderSelection.target
        )
        store.addTask {
            let source = try await vaultClient.createSource(vault, seed)
            try store.send(.sourceCaptured(source))
        }
    }

    private func captureSource(
        store: FeatureStore<State, Action>,
        state: inout State,
        rawURL: String
    ) {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            state.captureError = "That doesn't look like a link."
            return
        }
        state.captureError = nil
        state.isCapturingSource = true
        let vault = state.vault
        let folder = state.folderSelection.target
        store.addTask {
            do {
                let html = try await pageClient.html(url)
                let extraction = ArticleExtractor.extract(html: html)
                let seed = SourceSeed(
                    title: extraction.title ?? url.host() ?? "Untitled",
                    content: extraction.text,
                    url: url,
                    author: extraction.author,
                    site: extraction.site ?? url.host(),
                    folder: folder
                )
                let source = try await vaultClient.createSource(vault, seed)
                try store.send(.sourceCaptured(source))
            } catch {
                try store.send(
                    .sourceCaptureFailed("Couldn't fetch that page — paste the text instead.")
                )
            }
        }
    }

    private func createCapturedDot(
        store: FeatureStore<State, Action>,
        vault: URL,
        seed: DotSeed
    ) {
        store.addTask {
            let dot = try await vaultClient.createDot(vault, seed)
            try store.send(.dotCaptured(dot))
        }
    }

    fileprivate func connectSelection(store: FeatureStore<State, Action>, state: inout State) {
        guard state.selection.count >= 2,
              let anchorID = state.selection.first,
              var anchor = state.dots.first(where: { $0.id == anchorID })
        else { return }
        for id in state.selection.dropFirst()
        where !anchor.references.contains(Reference(id)) {
            anchor.references.append(Reference(id))
        }
        state.dots = state.dots.map { $0.id == anchorID ? anchor : $0 }
        persistDot(store: store, vault: state.vault, dot: anchor)
    }

    fileprivate func disconnectSelection(store: FeatureStore<State, Action>, state: inout State) {
        let selected = Set(state.selection.map(\.rawValue))
        guard selected.count >= 2 else { return }
        var changed: [Dot] = []
        state.dots = state.dots.map { dot in
            guard selected.contains(dot.id.rawValue) else { return dot }
            var updated = dot
            updated.references.removeAll { selected.contains($0.rawValue) }
            if updated.references != dot.references {
                changed.append(updated)
            }
            return updated
        }
        let vault = state.vault
        let toPersist = changed
        store.addTask {
            for dot in toPersist {
                try await vaultClient.updateDot(vault, dot)
            }
        }
    }

    fileprivate func applyVoiceSegment(_ segment: SpeechSegment, state: inout State) {
        guard var voice = state.voice, !voice.isCleaning else { return }
        voice.apply(segment)
        state.voice = voice
    }

    fileprivate func startVoiceCapture(store: FeatureStore<State, Action>, state: inout State) {
        state.captureError = nil
        state.voice = VoiceCapture()
        state.voiceTargetID = state.focusedDot?.id
        store.addTask(id: voiceStream) {
            do {
                for try await segment in speechClient.readySegments() {
                    try store.send(.voiceSegment(segment))
                }
                try store.send(.voiceCaptureEnded)
            } catch is CancellationError {
                // The stop gesture already wound the capture down.
            } catch {
                try store.send(.voiceCaptureFailed(VoiceFlow.describe(error)))
            }
        }
    }

    /// Stops listening; the settled speech gets the Wispr-grade cleanup,
    /// then lands as an idea in the current folder.
    fileprivate func finishVoiceCapture(
        store: FeatureStore<State, Action>,
        state: inout State,
        cancelStream: Bool
    ) {
        guard var voice = state.voice, !voice.isCleaning else { return }
        if cancelStream {
            store.addTask {
                voiceStream.cancel()
            }
        }
        let committed = voice.committed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !committed.isEmpty else {
            state.voice = nil
            return
        }
        voice.isCleaning = true
        voice.volatile = ""
        state.voice = voice
        store.addTask {
            let cleaned = await VoiceFlow.cleaned(committed, modelClient: modelClient)
            try store.send(.voiceCleaned(cleaned))
        }
    }

    /// Two (or more) ideas become one higher-level idea: the child records
    /// its lineage as references and lands pinned just above the parents'
    /// centroid, open for editing.
    private func synthesizeSelection(store: FeatureStore<State, Action>, state: inout State) {
        let parents = state.selection
        guard parents.count >= 2 else { return }
        let positions = state.positions
        let points = parents.compactMap { positions[$0] }
        var target = state.viewport.canvasPoint(fromViewportPoint: CGPoint(x: 320, y: 240))
        if !points.isEmpty {
            let centroidX = points.map(\.x).reduce(0, +) / CGFloat(points.count)
            let topY = points.map(\.y).min() ?? 0
            target = CGPoint(x: centroidX, y: topY - 200)
        }
        let vault = state.vault
        let seed = DotSeed(
            content: "New insight",
            references: parents.map { Reference($0) },
            folder: state.folderSelection.target
        )
        store.addTask {
            let dot = try await vaultClient.createDot(vault, seed)
            try store.send(.dotCreated(dot, target))
        }
    }
}

// MARK: - Proposal review rows

extension Ideas {
    /// One reviewable row: a drafted idea, the proposal it belongs to, and
    /// the source it came from.
    public struct PendingIdea: Equatable, Identifiable, Sendable {
        public var idea: ProposedIdea
        public var proposalId: IdeaProposal.ID
        public var source: Source?

        public var id: String { "\(proposalId.rawValue)-\(idea.id)" }
    }
}

extension Ideas.State {
    public var focusedPendingIdea: Ideas.PendingIdea? {
        pendingSelection.last.flatMap { id in visiblePendingIdeas.first { $0.id == id } }
    }

    public var focusedDot: Dot? {
        selection.last.flatMap { id in dots.first { $0.id == id } }
    }

    public var openSource: Source? {
        openSourceID.flatMap { id in sources.first { $0.id == id } }
    }

    public var positions: [Dot.ID: CGPoint] {
        CanvasLayout.positions(for: dots, arrangement: arrangement)
    }

    public var selectedDots: [Dot] {
        selection.compactMap { id in dots.first { $0.id == id } }
    }

    public var visibleDots: [Dot] {
        switch folderSelection {
        case .all: dots
        case .inbox: dots.filter { $0.folder == nil }
        case .folder(let name): dots.filter { $0.folder == name }
        }
    }

    public var visibleSources: [Source] {
        switch folderSelection {
        case .all: sources
        case .inbox: sources.filter { $0.folder == nil }
        case .folder(let name): sources.filter { $0.folder == name }
        }
    }

    /// True when every pair in the selection is already referenced
    /// (either direction) — the menu offers Disconnect instead of Connect.
    public var isSelectionFullyConnected: Bool {
        let selected = selectedDots
        guard selected.count >= 2 else { return false }
        for (index, first) in selected.enumerated() {
            for second in selected.dropFirst(index + 1) {
                let connected = first.references.contains(Reference(second.id))
                    || second.references.contains(Reference(first.id))
                if !connected { return false }
            }
        }
        return true
    }

    /// Ideas that reference this one — computed, never stored.
    public func backlinks(of id: Dot.ID) -> [Dot] {
        dots.filter { $0.references.contains(Reference(id)) }
    }

    public func dot(for reference: Reference) -> Dot? {
        dots.first { $0.id.rawValue == reference.rawValue }
    }

    public func source(for reference: Reference) -> Source? {
        sources.first { $0.id.rawValue == reference.rawValue }
    }

    /// Pending AI-drafted ideas surfaced inline in the ideas list —
    /// visibly provisional (they are not vault files) until the writer
    /// accepts or discards each one. Scoped by the source's folder.
    public var visiblePendingIdeas: [Ideas.PendingIdea] {
        proposals.filter { $0.status == .open }.flatMap { proposal -> [Ideas.PendingIdea] in
            let source = sources.first { $0.id == proposal.sourceId }
            let matches = switch folderSelection {
            case .all: true
            case .inbox: source?.folder == nil
            case .folder(let name): source?.folder == name
            }
            guard matches else { return [] }
            return proposal.pendingIdeas.map {
                Ideas.PendingIdea(idea: $0, proposalId: proposal.id, source: source)
            }
        }
    }
}
