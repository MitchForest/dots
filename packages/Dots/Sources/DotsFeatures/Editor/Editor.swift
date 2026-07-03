public import ComposableArchitecture2
public import DotsDomain
public import Foundation
import Dependencies
import DotsClients
public import DotsEngine

/// Posted when the writer leaves the editor; the parent tears it down and
/// refreshes its document list.
/// Posted when a ⌘P hit points outside the editor; the workspace reveals
/// it in the ideas pane.
enum IdeasRevealRequested: FeatureEventKey {
    typealias Value = VaultSearchHit
}

enum EditorClosed: FeatureEventKey {
    typealias Value = Void
}

/// A live dictation: finalized speech commits at `location` (which
/// advances); the current volatile hypothesis renders ghost-styled after it.
public struct DictationRun: Equatable, Sendable {
    /// Where the dictation began — the cleanup pass covers start..<location.
    public var start: Int
    /// Where the next finalized text lands.
    public var location: Int
    /// Length of the current volatile hypothesis after `location`.
    public var volatileLength: Int
    /// Spacing inserted before the first words so speech never welds onto
    /// existing text.
    public var glue: String

    public init(start: Int, location: Int, volatileLength: Int = 0, glue: String = "") {
        self.glue = glue
        self.location = location
        self.start = start
        self.volatileLength = volatileLength
    }
}

/// The Tab-summoned ghost completion: where the dimmed continuation sits in
/// the content until the writer accepts (Tab) or dismisses (esc/backspace).
public struct GhostRun: Equatable, Sendable {
    /// UTF-16 location where the ghost text begins.
    public var location: Int
    /// Current length of the streamed ghost text (glue included).
    public var length: Int
    /// Mechanical spacing prepended so the reply never welds onto the
    /// preceding word; applied when the reply lacks its own whitespace.
    public var glue: String

    public init(location: Int, length: Int, glue: String = "") {
        self.glue = glue
        self.length = length
        self.location = location
    }
}

/// One in-flight writing assist: where the streamed text lands and what it
/// replaces (so cancel can restore).
public struct AssistRun: Equatable, Sendable {
    public var kind: AssistKind
    /// UTF-16 location of the replaced region in the content.
    public var location: Int
    /// Current length of the streamed region (grows with each snapshot).
    public var length: Int
    /// What the region held before the assist — restored on cancel.
    public var original: String

    public init(kind: AssistKind, location: Int, length: Int, original: String) {
        self.kind = kind
        self.length = length
        self.location = location
        self.original = original
    }
}

@Feature
public struct Editor {
    public struct State: Equatable {
        public var assist: AssistRun?
        public var assistError: String?
        public var content = ""
        public var dictation: DictationRun?
        public var documentURL: URL
        public var ghost: GhostRun?
        public var frontmatter = ""
        /// Focus dims everything outside the caret's paragraph. One mode,
        /// one toggle (⌘D) — scopes were confusing.
        public var isFocusEnabled = false
        public var isTypewriterEnabled = false
        /// Presentation of the one always-editable buffer: raw markdown or
        /// rich (concealed syntax). Rich is the opinionated default.
        public var isMarkdownMode = false
        public var quickOpen: QuickOpen.State?
        /// The ideas this draft references (`ideas:` frontmatter), resolved
        /// for the strip above the text.
        public var referencedIdeas: [Dot] = []
        public var savedContent = ""
        public var vault: URL

        public var isDirty: Bool { content != savedContent }

        public var title: String {
            DocumentTitle.parse(FrontmatterBlock.join(frontmatter: frontmatter, body: content))
                ?? documentURL.deletingPathExtension().lastPathComponent
        }

        public var wordCount: Int { TextMetrics.wordCount(in: content) }

        public init(vault: URL, documentURL: URL) {
            self.documentURL = documentURL
            self.vault = vault
        }
    }

    public enum Action {
        case assistCancelled
        case assistFailed(String)
        case assistFinished
        case assistProviderResolved(ModelProvider, AssistRun, prompt: String)
        case assistRequested(AssistKind, location: Int, length: Int)
        case assistStreamed(String)
        case backButtonTapped
        case contentLoaded(String)
        case dictationFailed(String)
        case dictationFinished
        case dictationSegment(SpeechSegment)
        case dictationToggled(location: Int)
        case documentRenamed(URL)
        case externalChangeDetected(String)
        case focusToggled
        case frontmatterSubmitted(String)
        case ghostAccepted
        case ghostDismissed
        case ghostFailed(String)
        case ghostProviderResolved(ModelProvider, GhostRun, prompt: String, instructions: String)
        case ghostRequested(location: Int)
        case ghostStreamed(String)
        case ideaDetached(Dot.ID)
        case ideasAttached([Dot.ID])
        case presentationToggled
        case promptAssistRequested(String, location: Int, length: Int)
        case quickOpen(QuickOpen.Action)
        case quickOpenButtonTapped
        case referencedIdeasLoaded([Dot])
        case saved(String)
        case titleSubmitted(String)
        case typewriterToggled
    }

    @StoreTaskID var assistStream
    @StoreTaskID var autosave
    @StoreTaskID var dictationStream
    @StoreTaskID var ghostStream

    @Dependency(\.continuousClock) var clock
    @Dependency(\.modelClient) var modelClient
    @Dependency(\.speechClient) var speechClient
    @Dependency(\.vaultClient) var vaultClient

    public init() {}

    public var body: some Feature {
        Update { state, action in
            switch action {
            case .assistCancelled:
                guard let assist = state.assist else { break }
                // Restore what the stream replaced; the writer keeps their words.
                let contents = state.content as NSString
                state.content = contents.replacingCharacters(
                    in: NSRange(location: assist.location, length: assist.length),
                    with: assist.original
                )
                state.assist = nil
                store.addTask {
                    assistStream.cancel()
                }
                scheduleAutosave(store: store, state: state)

            case .assistFailed(let message):
                if let assist = state.assist {
                    let contents = state.content as NSString
                    state.content = contents.replacingCharacters(
                        in: NSRange(location: assist.location, length: assist.length),
                        with: assist.original
                    )
                }
                state.assist = nil
                state.assistError = message

            case .assistFinished:
                state.assist = nil
                scheduleAutosave(store: store, state: state)

            case .assistProviderResolved(let provider, let run, let prompt):
                // The run was staked out synchronously at request time (it
                // gates autosave); this just starts the stream.
                let request = ModelRequest(
                    provider: provider,
                    prompt: prompt,
                    instructions: AssistPrompt.instructions(for: run.kind)
                )
                store.addTask(id: assistStream) {
                    do {
                        for try await snapshot in modelClient.stream(request) {
                            try store.send(.assistStreamed(snapshot))
                        }
                        try store.send(.assistFinished)
                    } catch is CancellationError {
                        // Cancel already restored the original text.
                    } catch {
                        try store.send(.assistFailed(error.localizedDescription))
                    }
                }

            case .assistRequested(let kind, let location, let length):
                requestAssist(kind: kind, location: location, length: length, store: store, state: &state)

            case .assistStreamed(let text):
                guard var assist = state.assist else { break }
                let contents = state.content as NSString
                state.content = contents.replacingCharacters(
                    in: NSRange(location: assist.location, length: assist.length),
                    with: text
                )
                assist.length = (text as NSString).length
                state.assist = assist

            case .backButtonTapped:
                let joined = FrontmatterBlock.join(frontmatter: state.frontmatter, body: state.content)
                let isDirty = state.isDirty
                let url = state.documentURL
                store.addTask {
                    if isDirty {
                        try? await vaultClient.writeDocument(url, joined)
                    }
                    try store.post(key: EditorClosed.self, value: ())
                }

            case .contentLoaded(let contents):
                let parts = FrontmatterBlock.split(contents)
                state.content = parts.body
                state.frontmatter = parts.frontmatter
                state.savedContent = parts.body

            case .dictationFailed(let message):
                finishDictation(store: store, state: &state, cancelStream: true)
                state.assistError = message

            case .dictationFinished:
                finishDictation(store: store, state: &state, cancelStream: false)

            case .dictationSegment(let segment):
                applyDictationSegment(segment, state: &state)

            case .dictationToggled(let location):
                if state.dictation != nil {
                    finishDictation(store: store, state: &state, cancelStream: true)
                } else {
                    startDictation(at: location, store: store, state: &state)
                }

            case .documentRenamed(let url):
                state.documentURL = url

            case .externalChangeDetected(let contents):
                // Only adopt outside edits while we hold no unsaved work;
                // otherwise the writer's in-flight words win.
                guard !state.isDirty else { break }
                let parts = FrontmatterBlock.split(contents)
                state.content = parts.body
                state.frontmatter = parts.frontmatter
                state.savedContent = parts.body

            case .focusToggled:
                state.isFocusEnabled.toggle()

            case .ghostAccepted:
                guard state.ghost != nil else { break }
                // The dimmed text becomes real; a still-running stream stops
                // at what's shown.
                state.ghost = nil
                store.addTask {
                    ghostStream.cancel()
                }
                scheduleAutosave(store: store, state: state)

            case .ghostDismissed:
                guard let ghost = state.ghost else { break }
                let contents = state.content as NSString
                state.content = contents.replacingCharacters(
                    in: NSRange(location: ghost.location, length: ghost.length),
                    with: ""
                )
                state.ghost = nil
                store.addTask {
                    ghostStream.cancel()
                }

            case .ghostFailed(let message):
                if let ghost = state.ghost {
                    let contents = state.content as NSString
                    state.content = contents.replacingCharacters(
                        in: NSRange(location: ghost.location, length: ghost.length),
                        with: ""
                    )
                }
                state.ghost = nil
                state.assistError = message

            case .ghostProviderResolved(let provider, let run, let prompt, let instructions):
                startGhostStream(provider: provider, run: run, prompt: prompt, instructions: instructions, store: store, state: &state)

            case .ghostRequested(let location):
                guard state.assist == nil, state.ghost == nil else { break }
                state.assistError = nil
                let contents = state.content as NSString
                let clamped = min(max(0, location), contents.length)
                let before = contents.substring(to: clamped)
                // The caret's position decides what a completion means:
                // finish this sentence, offer the next one, or the next
                // list item — always concise, never a paragraph.
                let position = CompletionPrompt.position(before: before)
                let run = GhostRun(
                    location: clamped,
                    length: 0,
                    glue: CompletionPrompt.leadingGlue(before: before)
                )
                let prompt = CompletionPrompt.prompt(
                    before: before,
                    after: contents.substring(from: clamped)
                )
                let instructions = CompletionPrompt.instructions(for: position)
                store.addTask {
                    let provider = await modelClient.readSelectedProvider()
                    try store.send(
                        .ghostProviderResolved(provider, run, prompt: prompt, instructions: instructions)
                    )
                }

            case .ghostStreamed(let text):
                guard var ghost = state.ghost else { break }
                // Glue only when the reply brings no whitespace of its own.
                let startsWithWhitespace = text.first?.isWhitespace == true
                let glued = startsWithWhitespace ? text : ghost.glue + text
                let contents = state.content as NSString
                state.content = contents.replacingCharacters(
                    in: NSRange(location: ghost.location, length: ghost.length),
                    with: glued
                )
                ghost.length = (glued as NSString).length
                state.ghost = ghost

            case .frontmatterSubmitted(let raw):
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                state.frontmatter = trimmed.isEmpty ? "" : trimmed + "\n\n"
                let joined = FrontmatterBlock.join(frontmatter: state.frontmatter, body: state.content)
                let url = state.documentURL
                store.addTask {
                    try await vaultClient.writeDocument(url, joined)
                }

            case .ideaDetached(let id):
                state.frontmatter = DraftIdeas.removing(id, from: state.frontmatter)
                state.referencedIdeas.removeAll { $0.id == id }
                persistFrontmatter(store: store, state: state)

            case .ideasAttached(let ids):
                if state.frontmatter.isEmpty {
                    // A draft without frontmatter gains the minimal block the
                    // strip needs.
                    state.frontmatter = "---\nideas: []\n---\n\n"
                }
                for id in ids {
                    state.frontmatter = DraftIdeas.adding(id, to: state.frontmatter)
                }
                persistFrontmatter(store: store, state: state)

            case .quickOpen(.dismissed):
                state.quickOpen = nil

            case .quickOpen(.documentSelected(let document)):
                state.quickOpen = nil
                switchDocument(to: document, store: store, state: &state)

            case .quickOpen(.hitSelected(let hit)):
                state.quickOpen = nil
                switch hit {
                case .draft(let document, _):
                    switchDocument(to: document, store: store, state: &state)
                case .idea, .source:
                    // Not the editor's to show: the workspace reveals it in
                    // the ideas pane.
                    store.addTask {
                        try store.post(key: IdeasRevealRequested.self, value: hit)
                    }
                }

            case .quickOpen:
                break

            case .quickOpenButtonTapped:
                state.quickOpen = QuickOpen.State(vault: state.vault)

            case .presentationToggled:
                state.isMarkdownMode.toggle()

            case .promptAssistRequested(let instruction, let location, let length):
                requestPromptAssist(
                    instruction: instruction,
                    location: location,
                    length: length,
                    store: store,
                    state: &state
                )

            case .referencedIdeasLoaded(let ideas):
                state.referencedIdeas = ideas

            case .saved(let contents):
                state.savedContent = contents

            case .titleSubmitted(let newTitle):
                let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != state.title else { break }
                let joined = FrontmatterBlock.join(frontmatter: state.frontmatter, body: state.content)
                let url = state.documentURL
                store.addTask {
                    try await vaultClient.writeDocument(url, joined)
                    let renamed = try await vaultClient.renameDocument(url, trimmed)
                    try store.send(.documentRenamed(renamed))
                }

            case .typewriterToggled:
                state.isTypewriterEnabled.toggle()
            }
        }
        .onMount(id: store.documentURL) { state in
            let url = state.documentURL
            store.addTask {
                let contents = (try? await vaultClient.readDocument(url)) ?? ""
                try store.send(.contentLoaded(contents))
                for await _ in vaultClient.documentChanges(url) {
                    let latest = (try? await vaultClient.readDocument(url)) ?? ""
                    try store.send(.externalChangeDetected(latest))
                }
            }
        }
        .onChange(of: store.frontmatter) { state in
            // Every path that can change the ideas list funnels through the
            // frontmatter: load, attach, detach, external edits, quick-open.
            resolveReferencedIdeas(store: store, state: state)
        }
        .onChange(of: store.content) { state in
            // Mid-stream assist snapshots, unaccepted ghost text, and live
            // dictation never hit disk; the finish/accept/dismiss handlers
            // schedule the save once the text has settled.
            guard state.assist == nil, state.ghost == nil, state.dictation == nil else { return }
            scheduleAutosave(store: store, state: state)
        }
        .ifLet(\.quickOpen, action: \.quickOpen) {
            QuickOpen()
        }
    }

    private func persistFrontmatter(store: FeatureStore<State, Action>, state: State) {
        let joined = FrontmatterBlock.join(frontmatter: state.frontmatter, body: state.content)
        let url = state.documentURL
        store.addTask {
            try await vaultClient.writeDocument(url, joined)
        }
    }

    private func resolveReferencedIdeas(store: FeatureStore<State, Action>, state: State) {
        let ids = DraftIdeas.ids(in: state.frontmatter)
        if ids.isEmpty {
            guard !state.referencedIdeas.isEmpty else { return }
            store.addTask {
                try store.send(.referencedIdeasLoaded([]))
            }
            return
        }
        let vault = state.vault
        store.addTask {
            let dots = try await vaultClient.listDots(vault)
            let byID = Dictionary(dots.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            try store.send(.referencedIdeasLoaded(ids.compactMap { byID[$0] }))
        }
    }
}

// MARK: - Assist requests

extension Editor {
    /// ⌘P document switch: flush unsaved work on the old document, swap the
    /// URL — the mount chain reloads the new one.
    fileprivate func switchDocument(
        to document: VaultDocument,
        store: FeatureStore<State, Action>,
        state: inout State
    ) {
        let previousJoined = FrontmatterBlock.join(
            frontmatter: state.frontmatter,
            body: state.content
        )
        let previousURL = state.documentURL
        let wasDirty = state.isDirty
        guard document.url != previousURL else { return }
        state.documentURL = document.url
        store.addTask {
            if wasDirty {
                try? await vaultClient.writeDocument(previousURL, previousJoined)
            }
        }
    }

    fileprivate func requestAssist(
        kind: AssistKind,
        location: Int,
        length: Int,
        store: FeatureStore<State, Action>,
        state: inout State
    ) {
        // Ask travels via promptAssistRequested (it carries the writer's
        // instruction).
        guard state.assist == nil, kind != .prompt else { return }
        state.assistError = nil
        let contents = state.content as NSString
        let clampedLocation = min(max(0, location), contents.length)
        let clampedLength = min(max(0, length), contents.length - clampedLocation)
        guard !kind.needsSelection || clampedLength > 0 else { return }
        let range = NSRange(location: clampedLocation, length: clampedLength)
        let run = AssistRun(
            kind: kind,
            location: clampedLocation,
            length: clampedLength,
            original: contents.substring(with: range)
        )
        let prompt = AssistPrompt.prompt(
            for: kind,
            selection: run.original,
            before: contents.substring(to: clampedLocation),
            after: contents.substring(from: clampedLocation + clampedLength)
        )
        state.assist = run
        store.addTask {
            let provider = await modelClient.readSelectedProvider()
            try store.send(.assistProviderResolved(provider, run, prompt: prompt))
        }
    }

    fileprivate func requestPromptAssist(
        instruction: String,
        location: Int,
        length: Int,
        store: FeatureStore<State, Action>,
        state: inout State
    ) {
        guard state.assist == nil else { return }
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.assistError = nil
        let contents = state.content as NSString
        let clampedLocation = min(max(0, location), contents.length)
        let clampedLength = min(max(0, length), contents.length - clampedLocation)
        guard clampedLength > 0 else { return }
        let range = NSRange(location: clampedLocation, length: clampedLength)
        let run = AssistRun(
            kind: .prompt,
            location: clampedLocation,
            length: clampedLength,
            original: contents.substring(with: range)
        )
        let prompt = AssistPrompt.customPrompt(
            instruction: trimmed,
            selection: run.original,
            before: contents.substring(to: clampedLocation),
            after: contents.substring(from: clampedLocation + clampedLength)
        )
        state.assist = run
        store.addTask {
            let provider = await modelClient.readSelectedProvider()
            try store.send(.assistProviderResolved(provider, run, prompt: prompt))
        }
    }
}

// MARK: - Ghost stream

extension Editor {
    fileprivate func startGhostStream(
        provider: ModelProvider,
        run: GhostRun,
        prompt: String,
        instructions: String,
        store: FeatureStore<State, Action>,
        state: inout State
    ) {
        state.ghost = run
        let request = ModelRequest(
            provider: provider,
            prompt: prompt,
            instructions: instructions,
            maxTokens: CompletionPrompt.maxTokens
        )
        store.addTask(id: ghostStream) {
            do {
                for try await snapshot in modelClient.stream(request) {
                    try store.send(.ghostStreamed(snapshot))
                }
                // Stream done; the ghost stays until Tab or esc.
            } catch is CancellationError {
                // Accept/dismiss already resolved the ghost.
            } catch {
                try store.send(.ghostFailed(error.localizedDescription))
            }
        }
    }
}

// MARK: - Dictation

extension Editor {
    fileprivate func startDictation(
        at location: Int,
        store: FeatureStore<State, Action>,
        state: inout State
    ) {
        guard state.assist == nil, state.ghost == nil else { return }
        state.assistError = nil
        let contents = state.content as NSString
        let clamped = min(max(0, location), contents.length)
        state.dictation = DictationRun(
            start: clamped,
            location: clamped,
            glue: CompletionPrompt.leadingGlue(before: contents.substring(to: clamped))
        )
        store.addTask(id: dictationStream) {
            do {
                for try await segment in speechClient.readySegments() {
                    try store.send(.dictationSegment(segment))
                }
                try store.send(.dictationFinished)
            } catch is CancellationError {
                // The stop gesture already wound the run down.
            } catch {
                try store.send(.dictationFailed(VoiceFlow.describe(error)))
            }
        }
    }

    fileprivate func applyDictationSegment(_ segment: SpeechSegment, state: inout State) {
        guard var run = state.dictation else { return }
        let needsGlue = run.location == run.start
            && segment.text.first?.isWhitespace != true
        let text = needsGlue ? run.glue + segment.text : segment.text
        let contents = state.content as NSString
        state.content = contents.replacingCharacters(
            in: NSRange(location: run.location, length: run.volatileLength),
            with: text
        )
        let length = (text as NSString).length
        if segment.isFinal {
            run.location += length
            run.volatileLength = 0
        } else {
            run.volatileLength = length
        }
        state.dictation = run
    }

    /// Stops listening: the volatile hypothesis is dropped (it was never
    /// settled), and the committed span gets the Wispr-grade cleanup pass.
    fileprivate func finishDictation(
        store: FeatureStore<State, Action>,
        state: inout State,
        cancelStream: Bool
    ) {
        guard let run = state.dictation else { return }
        if run.volatileLength > 0 {
            let contents = state.content as NSString
            state.content = contents.replacingCharacters(
                in: NSRange(location: run.location, length: run.volatileLength),
                with: ""
            )
        }
        state.dictation = nil
        if cancelStream {
            store.addTask {
                dictationStream.cancel()
            }
        }
        let span = run.location - run.start
        if span > 0 {
            requestAssist(
                kind: .cleanupDictation,
                location: run.start,
                length: span,
                store: store,
                state: &state
            )
        } else {
            scheduleAutosave(store: store, state: state)
        }
    }
}

// MARK: - Autosave

extension Editor {
    fileprivate func scheduleAutosave(store: FeatureStore<State, Action>, state: State) {
        guard state.isDirty else { return }
        let body = state.content
        let joined = FrontmatterBlock.join(frontmatter: state.frontmatter, body: body)
        let url = state.documentURL
        let vault = state.vault
        let wordsDelta = TextMetrics.wordCount(in: body)
            - TextMetrics.wordCount(in: state.savedContent)
        store.addTask(id: autosave) {
            try await clock.sleep(for: .seconds(1))
            try await vaultClient.writeDocument(url, joined)
            try store.send(.saved(body))
            if wordsDelta > 0 {
                try? await vaultClient.recordWordsWritten(vault, wordsDelta)
            }
        }
    }
}
