import ComposableArchitecture2
import DotsDomain
import DotsEngine
import DotsUI
import SwiftUI

/// The writing pane: chrome-free — its controls live in the workspace's
/// single toolbar, and frontmatter lives behind the title's info popover.
/// Ideas sent to the draft sit in a structured strip above the text, never
/// in it.
struct EditorScreen: View {
    @Bindable private var store: StoreOf<Editor>
    private let isChromeFaded: Bool

    @State private var askDraft = ""
    @State private var askRange: NSRange?
    @State private var counterReveal: Task<Void, Never>?
    @State private var formatBarAnchor: CGRect?
    @State private var isCounterVisible = true

    init(store: StoreOf<Editor>, isChromeFaded: Bool = false) {
        self.isChromeFaded = isChromeFaded
        self.store = store
    }

    var body: some View {
        VStack(spacing: 0) {
            if !store.referencedIdeas.isEmpty {
                ideaStrip
                    .opacity(isChromeFaded ? 0 : 1)
                    .animation(
                        .easeInOut(duration: isChromeFaded ? 0.7 : 0.25),
                        value: isChromeFaded
                    )
            }

            MarkdownTextView(
                text: $store.content,
                isRich: !store.isMarkdownMode,
                isFocusMode: store.isFocusEnabled,
                isTypewriter: store.isTypewriterEnabled,
                isAssistRunning: store.assist != nil,
                ghostRange: store.ghost.map { NSRange(location: $0.location, length: $0.length) },
                dictationVolatileRange: store.dictation.flatMap { run in
                    run.volatileLength > 0
                        ? NSRange(location: run.location, length: run.volatileLength)
                        : nil
                },
                isDictating: store.dictation != nil,
                onAskRequested: { range in
                    askRange = range
                    askDraft = ""
                },
                onDictationToggle: { location in
                    store.send(.dictationToggled(location: location))
                },
                onAssist: { kind, range in
                    store.send(.assistRequested(kind, location: range.location, length: range.length))
                },
                onCancelAssist: { store.send(.assistCancelled) },
                onGhostAccept: { store.send(.ghostAccepted) },
                onGhostDismiss: { store.send(.ghostDismissed) },
                onGhostRequest: { location in store.send(.ghostRequested(location: location)) },
                formatBarAnchor: $formatBarAnchor
            )
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) {
                // Selection controls live in one calm place — a pill at the
                // bottom of the writing pane — never on top of the selection
                // itself (select-all made anchored bubbles impossible). Ask
                // swaps into the same spot.
                if let range = askRange, formatBarAnchor != nil {
                    AskBarView(
                        draft: $askDraft,
                        onCancel: { askRange = nil },
                        onSubmit: {
                            askRange = nil
                            store.send(
                                .promptAssistRequested(
                                    askDraft,
                                    location: range.location,
                                    length: range.length
                                )
                            )
                        }
                    )
                    .padding(.bottom, DotsSpacing.lg)
                    .transition(.opacity)
                } else if formatBarAnchor != nil {
                    FormatBarView()
                        .padding(.bottom, DotsSpacing.lg)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: formatBarAnchor == nil)
            .onChange(of: formatBarAnchor) { _, anchor in
                if anchor == nil {
                    askRange = nil
                }
            }
        }
        .background(DotsColor.Background.primary.ignoresSafeArea())
        .overlay(alignment: .bottomLeading) {
            // The whisper: word count hides while you type, returns when
            // you pause. iA's stats-bar temperament. Focus and typewriter
            // state ride along so invisible modes stay legible. Bottom-left:
            // the bottom-right corner belongs to the mic FAB.
            // Faded chrome silences the word count too; only messages the
            // writer just caused (dictation, ghost, assist, errors) may
            // still whisper.
            let hasActiveStatus = store.assist != nil || store.ghost != nil
                || store.dictation != nil || store.assistError != nil
            DotsMetaLabel(whisperText)
                .padding(.horizontal, DotsSpacing.sm)
                .padding(.vertical, DotsSpacing.xs)
                .background(Capsule().fill(.regularMaterial))
                .padding(DotsSpacing.md)
                .opacity(hasActiveStatus || (isCounterVisible && !isChromeFaded) ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: isCounterVisible)
                .animation(
                    .easeInOut(duration: isChromeFaded ? 0.7 : 0.25),
                    value: isChromeFaded
                )
                .allowsHitTesting(false)
        }
        .onChange(of: store.content) {
            isCounterVisible = false
            counterReveal?.cancel()
            counterReveal = Task {
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                isCounterVisible = true
            }
        }
        .overlay(alignment: .top) {
            if let quickOpenStore = store.scope(\.quickOpen, action: \.quickOpen) {
                QuickOpenView(store: quickOpenStore)
            }
        }
    }

    private var whisperText: String {
        if store.dictation != nil {
            return "LISTENING… ESC OR MIC TO STOP"
        }
        if store.ghost != nil {
            return "TAB TO ACCEPT · ESC TO DISMISS"
        }
        if let assist = store.assist {
            return "\(assist.kind.displayName.uppercased())… ESC TO CANCEL"
        }
        if let error = store.assistError {
            return "ASSIST FAILED — \(error.uppercased())"
        }
        var parts = ["\(store.wordCount) WORDS"]
        if store.isFocusEnabled {
            parts.append("FOCUS (⌘D)")
        }
        if store.isTypewriterEnabled {
            parts.append("TYPEWRITER (⌥⌘T)")
        }
        return parts.joined(separator: " · ")
    }

    /// The raw material this draft draws on — structured references, read in
    /// place, detached with ×. Never part of the prose.
    private var ideaStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DotsSpacing.xs) {
                DotsMetaLabel("IDEAS")
                ForEach(store.referencedIdeas) { idea in
                    IdeaStripChipView(
                        idea: idea,
                        onDetach: { store.send(.ideaDetached(idea.id)) }
                    )
                }
            }
            .padding(.horizontal, DotsSpacing.lg)
            .padding(.vertical, DotsSpacing.sm)
        }
        .background(DotsColor.Background.primary)
    }
}

/// One referenced idea in the strip: glyph + title; click reads the whole
/// idea, × detaches it from the draft.
private struct IdeaStripChipView: View {
    let idea: Dot
    let onDetach: () -> Void

    @State private var isReading = false

    var body: some View {
        HStack(spacing: DotsSpacing.xs) {
            Button {
                isReading = true
            } label: {
                HStack(spacing: DotsSpacing.xs) {
                    DotProvenanceGlyph(isExtraction: idea.isExtraction)
                    Text(DotPreview.title(idea.content))
                        .font(DotsTypography.footnote)
                        .foregroundStyle(DotsColor.Ink.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Read this idea")

            Button(action: onDetach) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(DotsColor.Ink.muted)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Detach from this draft")
        }
        .padding(.horizontal, DotsSpacing.sm)
        .padding(.vertical, DotsSpacing.xs)
        .frame(maxWidth: 260)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(DotsColor.Surface.control)
        )
        .popover(isPresented: $isReading, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: DotsSpacing.sm) {
                HStack(spacing: DotsSpacing.xs) {
                    DotProvenanceGlyph(isExtraction: idea.isExtraction)
                    DotsMetaLabel(
                        idea.capturedAt.formatted(date: .abbreviated, time: .omitted).uppercased()
                    )
                }
                ScrollView {
                    Text(idea.content)
                        .font(DotsTypography.body)
                        .lineSpacing(3)
                        .foregroundStyle(DotsColor.Ink.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 260)
                if !idea.tags.isEmpty {
                    DotTagChipsView(tags: idea.tags, wraps: true)
                }
            }
            .padding(DotsSpacing.md)
            .frame(width: 340)
        }
    }
}

#Preview {
    EditorScreen(
        store: Store(
            initialState: Editor.State(
                vault: URL(filePath: "/mock/vault", directoryHint: .isDirectory),
                documentURL: URL(filePath: "/mock/vault/drafts/why-we-write.md")
            )
        ) {
            Editor()
        }
    )
    .frame(width: 1000, height: 700)
}
