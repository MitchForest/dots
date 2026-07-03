import AppKit
import DotsUI
import SwiftUI

/// The floating format bar: appears above a settled selection, sends format
/// selectors down the responder chain (same commands as the Format menu),
/// and vanishes the moment the selection collapses.
struct FormatBarView: View {
    var body: some View {
        HStack(spacing: 2) {
            iconButton("bold", selector: "dotsToggleBold:", help: "Bold (⌘B)")
            iconButton("italic", selector: "dotsToggleItalic:", help: "Italic (⌘I)")
            iconButton(
                "strikethrough",
                selector: "dotsToggleStrikethrough:",
                help: "Strikethrough (⌘⇧X)"
            )
            iconButton(
                "chevron.left.forwardslash.chevron.right",
                selector: "dotsToggleCode:",
                help: "Code (⌘E)"
            )
            iconButton("link", selector: "dotsInsertLink:", help: "Link (⌘K)")

            divider

            textButton("H1", selector: "dotsHeading1:", help: "Heading 1 (⌘1)")
            textButton("H2", selector: "dotsHeading2:", help: "Heading 2 (⌘2)")
            textButton("H3", selector: "dotsHeading3:", help: "Heading 3 (⌘3)")

            divider

            iconButton("list.bullet", selector: "dotsToggleBullet:", help: "Bullet list (⌘⇧8)")
            iconButton("text.quote", selector: "dotsToggleQuote:", help: "Quote (⌘⇧9)")

            divider

            assistMenu
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(DotsColor.Background.hairline, lineWidth: 0.5)
        )
        .dotsElevation(.floating)
    }

    /// The AI verbs, behind one sparkle — same responder-chain selectors as
    /// the Format menu's Writing Assists section.
    private var assistMenu: some View {
        Menu {
            Button("Fix grammar") { send("dotsAssistFixGrammar:") }
            Button("Tighten") { send("dotsAssistTighten:") }
            Button("Expand") { send("dotsAssistExpand:") }
            Button("Format as markdown") { send("dotsAssistFormatMarkdown:") }
            Divider()
            Button("Ask AI…") { send("dotsAssistAsk:") }
        } label: {
            Text("AI")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DotsColor.brand)
                .frame(width: 28, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Writing assists")
    }

    private func send(_ selector: String) {
        NSApp.sendAction(Selector((selector)), to: nil, from: nil)
    }
}

/// The Ask input: one field, floating where the format bar floats. Return
/// runs the instruction on the selection; esc backs out.
struct AskBarView: View {
    @Binding var draft: String
    let onCancel: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DotsSpacing.xs) {
            Text("AI")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DotsColor.brand)

            TextField("Ask — e.g. turn into bullet points", text: $draft)
                .textFieldStyle(.plain)
                .font(DotsTypography.footnote)
                .foregroundStyle(DotsColor.Ink.primary)
                .frame(width: 260)
                .focused($isFocused)
                .onSubmit {
                    if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                        onSubmit()
                    }
                }
                .onKeyPress(.escape) {
                    onCancel()
                    return .handled
                }
        }
        .padding(.horizontal, DotsSpacing.sm)
        .padding(.vertical, DotsSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(DotsColor.Background.hairline, lineWidth: 0.5)
        )
        .dotsElevation(.floating)
        .onAppear { isFocused = true }
    }
}

extension FormatBarView {
    private var divider: some View {
        Rectangle()
            .fill(DotsColor.Background.hairline)
            .frame(width: 1, height: 14)
            .padding(.horizontal, 2)
    }

    private func iconButton(_ symbol: String, selector: String, help: String) -> some View {
        Button {
            NSApp.sendAction(Selector((selector)), to: nil, from: nil)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DotsColor.Ink.secondary)
                .frame(width: 28, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func textButton(_ title: String, selector: String, help: String) -> some View {
        Button {
            NSApp.sendAction(Selector((selector)), to: nil, from: nil)
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DotsColor.Ink.secondary)
                .frame(width: 28, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
