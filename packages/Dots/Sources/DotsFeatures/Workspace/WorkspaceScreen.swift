public import ComposableArchitecture2
import AppKit
import DotsUI
public import SwiftUI

/// The workspace shell. Chrome follows the placement doctrine: window-scope
/// controls live in the native titlebar, pane chrome floats inside panes,
/// selection actions live in context menus.
struct WorkspaceScreen: View {
    @AppStorage("blog.dots.editor-markdown-mode") private var prefersMarkdownMode = false
    @AppStorage("blog.dots.editor-on-left") private var isEditorOnLeft = true
    @Bindable private var store: StoreOf<Workspace>

    @State private var canvasWidth: CGFloat = 460
    @State private var frontmatterDraft = ""
    // Chrome fades once typing is sustained; any mouse movement restores it.
    @State private var isChromeFaded = false
    @State private var lastHoverPoint: CGPoint?
    @State private var lastKeystrokeAt: Date?
    @State private var typingBurstStart: Date?
    // Fresh per document: writing starts full-width; the canvas appears only
    // when the writer summons it.
    @State private var isCanvasVisible = false
    @State private var isFrontmatterPresented = false
    @State private var isVoicePopoverPresented = false
    @State private var titleDraft = ""

    @FocusState private var isTitleFocused: Bool

    init(store: StoreOf<Workspace>) {
        self.store = store
    }

    private var hasEditor: Bool {
        store.editor != nil
    }

    var body: some View {
        split
            .overlay(alignment: .bottomTrailing) {
                if isMicAvailable {
                    micFab
                        // The mic dims with the chrome — unless it's
                        // recording, when it's the stop control.
                        .opacity(isChromeFaded && !isRecording ? 0 : 1)
                        .animation(
                            .easeInOut(duration: isChromeFaded ? 0.7 : 0.25),
                            value: isChromeFaded
                        )
                        .allowsHitTesting(!isChromeFaded || isRecording)
                        .padding(DotsSpacing.md)
                }
            }
            .background(DotsColor.Background.primary.ignoresSafeArea())
            .navigationTitle("")
            .toolbar { toolbarContent }
            // The system titlebar material adapts to what sits beneath it
            // (scroll views, panes, plain color), which made the bar shift
            // color between views. Hide it: the bar is always our paper.
            .toolbarBackground(.hidden, for: .windowToolbar)
            // The Rich/Markdown choice persists: apply the preference when
            // an editor appears, remember it when the writer flips.
            .onChange(of: hasEditor, initial: true) { _, isOpen in
                if isOpen, store.editor?.isMarkdownMode != prefersMarkdownMode {
                    store.send(.editor(.presentationToggled))
                }
            }
            .onChange(of: store.editor?.isMarkdownMode) { _, mode in
                if let mode {
                    prefersMarkdownMode = mode
                }
            }
            // The typewriter contract: sustained typing fades the chrome to
            // nothing (all modes — calm is not a mode); touching the mouse
            // brings it back. A ~1s commitment threshold prevents strobing
            // during mouse-heavy surgical edits.
            .onChange(of: store.editor?.content) {
                guard hasEditor else { return }
                let now = Date()
                defer { lastKeystrokeAt = now }
                // A pause over ~2s ends the burst: the next keystroke starts
                // a fresh one instead of inheriting a stale timer.
                if let last = lastKeystrokeAt, now.timeIntervalSince(last) > 2.0 {
                    typingBurstStart = now
                    return
                }
                if let start = typingBurstStart {
                    if now.timeIntervalSince(start) > 1.0, !isChromeFaded {
                        isChromeFaded = true
                    }
                } else {
                    typingBurstStart = now
                }
            }
            .onContinuousHover(coordinateSpace: .global) { phase in
                switch phase {
                case .active(let point):
                    defer { lastHoverPoint = point }
                    guard let previous = lastHoverPoint else { return }
                    // Palm-on-trackpad noise while typing must not count as
                    // movement — demand real travel.
                    let distance = hypot(point.x - previous.x, point.y - previous.y)
                    guard distance > 2 else { return }
                    if isChromeFaded {
                        // Faded chrome ignores mouse activity inside the
                        // writing area; only reaching the titlebar itself
                        // restores — not the top stretch of the prose.
                        if point.y < 40 {
                            isChromeFaded = false
                            typingBurstStart = nil
                        }
                    } else {
                        typingBurstStart = nil
                    }
                case .ended:
                    // The pointer left the content area. If it left near the
                    // top it's IN the titlebar now (which sends no content
                    // hover events) — that counts as reaching for the chrome.
                    // Fast moves can jump the 40pt band entirely, so this is
                    // the catch that keeps the chrome from getting stuck.
                    if isChromeFaded, let last = lastHoverPoint, last.y < 120 {
                        isChromeFaded = false
                        typingBurstStart = nil
                    }
                    lastHoverPoint = nil
                }
            }
            .onChange(of: hasEditor) { _, isOpen in
                if !isOpen {
                    typingBurstStart = nil
                    isChromeFaded = false
                }
            }
            // Focus mode is an explicit gesture: ⌘D dims the room with the
            // text — immediately, not after a typing burst — and leaving it
            // brings everything back.
            .onChange(of: store.editor?.isFocusEnabled) { _, isFocused in
                guard let isFocused else { return }
                typingBurstStart = nil
                isChromeFaded = isFocused
            }
            .background(WindowChromeFader(isFaded: isChromeFaded))
            .background(hasEditor ? hiddenEditorShortcuts : nil)
    }

    // MARK: Split

    @ViewBuilder private var split: some View {
        if hasEditor {
            HStack(spacing: 0) {
                if isEditorOnLeft {
                    editorPane
                    if isCanvasVisible {
                        sidePanel(edge: .trailing)
                    }
                } else {
                    if isCanvasVisible {
                        sidePanel(edge: .leading)
                    }
                    editorPane
                }
            }
        } else {
            canvasPane
        }
    }

    @ViewBuilder private var editorPane: some View {
        if let editorStore = store.scope(\.editor, action: \.editor) {
            EditorScreen(store: editorStore, isChromeFaded: isChromeFaded)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var canvasPane: some View {
        // Full window gets the three-pane shell; beside the editor the
        // compact layout keeps the panel focused.
        IdeasScreen(
            store: store.scope(\.ideas, action: \.ideas),
            layout: hasEditor ? .compact : .full
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sidePanel(edge: Edge) -> some View {
        HStack(spacing: 0) {
            if edge == .trailing {
                dividerHandle
            }
            canvasPane
                .frame(width: canvasWidth)
                .clipped()
            if edge == .leading {
                dividerHandle
            }
        }
        .transition(.move(edge: edge))
    }

    private var dividerHandle: some View {
        Rectangle()
            .fill(DotsColor.Background.hairline)
            .frame(width: 1)
            .overlay(
                Color.clear
                    .frame(width: 9)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let delta = isEditorOnLeft
                                    ? -value.translation.width
                                    : value.translation.width
                                canvasWidth = min(760, max(300, canvasWidth + delta))
                            }
                    )
            )
    }

    // MARK: Native titlebar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        // Icon-only buttons keep the system glass bubble (default toolbar
        // treatment); text controls opt out via sharedBackgroundVisibility.
        // Items are never removed for the fade: the whole titlebar container
        // fades as one (WindowChromeFader), so glass, title, and buttons dim
        // together and every shortcut keeps working.
        Group {
            ToolbarItem(placement: .navigation) {
                Button {
                    store.send(.closeButtonTapped)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .keyboardShortcut(.cancelAction)
                .help("Back to home (esc)")
            }

            if hasEditor {
                ToolbarItem(placement: .principal) {
                    centeredTitle
                }
                .sharedBackgroundVisibility(.hidden)

                // Words for modes: two presentations of one always-editable
                // buffer — no lock, no read-only.
                ToolbarItem(placement: .primaryAction) {
                    presentationToggle
                        .fixedSize()
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarSpacer(.fixed, placement: .primaryAction)

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.editor(.quickOpenButtonTapped))
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .keyboardShortcut("p", modifiers: .command)
                    .help("Open another document (⌘P)")
                }
            }

            if hasEditor, isCanvasVisible {
                ToolbarSpacer(.fixed, placement: .primaryAction)

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isEditorOnLeft.toggle()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                    .help("Swap writing and ideas sides")
                }
            }

            if hasEditor {
                ToolbarSpacer(.fixed, placement: .primaryAction)

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isCanvasVisible.toggle()
                        }
                    } label: {
                        Image(systemName: isCanvasVisible ? "sidebar.trailing" : "sidebar.leading")
                            .foregroundStyle(isCanvasVisible ? DotsColor.brand : DotsColor.Ink.secondary)
                    }
                    .keyboardShortcut("\\", modifiers: .command)
                    .help(isCanvasVisible ? "Hide ideas (⌘\\)" : "Show ideas (⌘\\)")
                }
            }
        }
    }

    /// Raw markdown or rich, same bytes underneath. ⌘⇧M flips.
    private var presentationToggle: some View {
        let isMarkdown = store.editor?.isMarkdownMode == true
        return HStack(spacing: 2) {
            presentationButton("Rich", isActive: !isMarkdown) {
                if isMarkdown {
                    store.send(.editor(.presentationToggled))
                }
            }
            presentationButton("Markdown", isActive: isMarkdown) {
                if !isMarkdown {
                    store.send(.editor(.presentationToggled))
                }
            }
        }
        .padding(2)
        .background(Capsule().fill(DotsColor.Surface.control))
        .help("Rich hides the syntax; Markdown shows every character (⌘⇧M)")
    }

    /// Writing-mode shortcuts without chrome: presentation (⌘⇧M), focus
    /// cycle (⌘D), typewriter scrolling (⌥⌘T).
    private var hiddenEditorShortcuts: some View {
        HStack(spacing: 0) {
            Button("") { store.send(.editor(.presentationToggled)) }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Button("") { store.send(.editor(.focusToggled)) }
                .keyboardShortcut("d", modifiers: .command)
            Button("") { store.send(.editor(.typewriterToggled)) }
                .keyboardShortcut("t", modifiers: [.command, .option])
            Button("") { sendEditorDictation() }
                .keyboardShortcut("m", modifiers: [.command, .option])
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func presentationButton(
        _ title: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(DotsTypography.footnote)
                .foregroundStyle(isActive ? DotsColor.Ink.inverse : DotsColor.Ink.secondary)
                .padding(.horizontal, DotsSpacing.sm)
                .padding(.vertical, 2)
                .background(Capsule().fill(isActive ? DotsColor.Ink.primary : .clear))
        }
        .buttonStyle(.plain)
    }

    /// The document title, centered and editable in place: click, type,
    /// Return. Renames the file and rewrites the frontmatter title.
    private var centeredTitle: some View {
        HStack(spacing: DotsSpacing.xs) {
            TextField("Untitled", text: $titleDraft)
                .textFieldStyle(.plain)
                .font(DotsTypography.callout)
                .foregroundStyle(DotsColor.Ink.primary)
                .multilineTextAlignment(.center)
                .fixedSize()
                .focused($isTitleFocused)
                .onSubmit {
                    store.send(.editor(.titleSubmitted(titleDraft)))
                    // Return means done: drop focus so the title doesn't sit
                    // there selected.
                    isTitleFocused = false
                }
                .help("Click to rename")

            Circle()
                .fill(DotsColor.Ink.muted)
                .frame(width: 6, height: 6)
                .opacity(store.editor?.isDirty == true ? 1 : 0)
                .accessibilityLabel(store.editor?.isDirty == true ? "Unsaved changes" : "")

            if let editor = store.editor, !editor.frontmatter.isEmpty {
                Button {
                    isFrontmatterPresented = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DotsColor.Ink.muted)
                }
                .buttonStyle(.plain)
                .help("View and edit frontmatter")
                .popover(isPresented: $isFrontmatterPresented, arrowEdge: .bottom) {
                    frontmatterEditor
                }
            }

        }
        .fixedSize()
        .frame(maxWidth: 420)
        .onChange(of: store.editor?.title, initial: true) { _, newTitle in
            if let newTitle {
                titleDraft = newTitle
            }
        }
    }

    private var frontmatterEditor: some View {
        VStack(alignment: .trailing, spacing: DotsSpacing.sm) {
            TextEditor(text: $frontmatterDraft)
                .onAppear {
                    // Populate here, not in the button action: presenting in
                    // the same tick as a state write can snapshot stale state.
                    frontmatterDraft = (store.editor?.frontmatter ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(DotsColor.Ink.primary)
                .scrollContentBackground(.hidden)
                .frame(width: 340, height: 150)

            Button("Save") {
                isFrontmatterPresented = false
                store.send(.editor(.frontmatterSubmitted(frontmatterDraft)))
            }
            .buttonStyle(.plain)
            .font(DotsTypography.callout)
            .foregroundStyle(DotsColor.brand)
        }
        .padding(DotsSpacing.md)
    }
}

// MARK: - Dictation FAB

extension WorkspaceScreen {
    // MARK: Dictation FAB — one mic per window, bottom-right

    /// With a draft open the mic is always there (the editor is the default
    /// target). Ideas-only, it appears exactly when there's a text box to
    /// type into: a real idea focused in the detail pane — never for the
    /// canvas, sources, pending proposals, or the empty placeholder.
    private var isMicAvailable: Bool {
        if hasEditor { return true }
        return store.ideas.tab == .ideas
            && !store.ideas.isCanvasView
            && store.ideas.focusedDot != nil
    }

    private var isRecording: Bool {
        store.ideas.voice != nil || store.editor?.dictation != nil
    }

    private var micFab: some View {
        Button(action: toggleDictation) {
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isRecording ? DotsColor.brand : DotsColor.Ink.secondary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(.regularMaterial))
        }
        .buttonStyle(.plain)
        .help(isRecording ? "Stop dictating (⌥⌘M)" : "Dictate into what you're writing (⌥⌘M)")
        .popover(isPresented: $isVoicePopoverPresented, arrowEdge: .top) {
            VoiceCaptureView(
                voice: store.ideas.voice,
                onStop: { store.send(.ideas(.voiceCaptureToggled)) }
            )
        }
        .onChange(of: store.ideas.voice == nil) { _, ended in
            if ended {
                isVoicePopoverPresented = false
            }
        }
    }

    /// Dictation follows keyboard focus: the markdown editor takes speech at
    /// the caret; an idea's text box takes it as a fresh paragraph. A running
    /// recording always stops from here, wherever focus wandered.
    private func toggleDictation() {
        if store.ideas.voice != nil {
            store.send(.ideas(.voiceCaptureToggled))
            return
        }
        if store.editor?.dictation != nil {
            sendEditorDictation()
            return
        }
        if hasEditor, !isIdeaTextFocused {
            sendEditorDictation()
        } else if store.ideas.focusedDot != nil {
            store.send(.ideas(.voiceCaptureToggled))
            isVoicePopoverPresented = true
        } else if hasEditor {
            sendEditorDictation()
        }
    }

    /// Menus' own pattern, completed: dispatch down the responder chain, and
    /// when nothing claims the action (focus was on a toolbar, or nowhere),
    /// focus the writing surface and retry. The caret stays wherever the
    /// writer left it — the text view owns it; the store never mirrors it.
    private func sendEditorDictation() {
        let selector = Selector(("dotsToggleDictation:"))
        if NSApp.sendAction(selector, to: nil, from: nil) { return }
        guard let window = NSApp.keyWindow,
              let textView = Self.formattingTextView(in: window.contentView)
        else { return }
        window.makeFirstResponder(textView)
        _ = NSApp.sendAction(selector, to: nil, from: nil)
    }

    private static func formattingTextView(in view: NSView?) -> FormattingTextView? {
        guard let view else { return nil }
        if let match = view as? FormattingTextView { return match }
        for subview in view.subviews {
            if let match = formattingTextView(in: subview) { return match }
        }
        return nil
    }

    /// The editor's surface is a `FormattingTextView`; any other focused
    /// text view (the idea editor, the tags field) belongs to the ideas pane.
    private var isIdeaTextFocused: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSTextView && !(responder is FormattingTextView)
    }
}
