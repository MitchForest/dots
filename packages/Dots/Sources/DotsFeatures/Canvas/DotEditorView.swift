import DotsDomain
import DotsUI
import SwiftUI

/// Quick-entry idea editor: opens with everything selected so typing
/// replaces. Return saves, ⇧Return inserts a newline, Esc cancels.
/// Model-blind — used from canvas card popovers and the distill gesture.
struct DotEditorView: View {
    let onCancel: () -> Void
    let onSave: (_ content: String, _ tags: [String]) -> Void

    @State private var content: String
    @State private var selection: TextSelection?
    @State private var tagsText: String
    @FocusState private var isContentFocused: Bool

    init(
        dot: Dot,
        onSave: @escaping (String, [String]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onCancel = onCancel
        self.onSave = onSave
        _content = State(initialValue: dot.content)
        _tagsText = State(initialValue: dot.tags.joined(separator: ", "))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.sm) {
            TextEditor(text: $content, selection: $selection)
                .font(DotsTypography.body)
                .foregroundStyle(DotsColor.Ink.primary)
                .scrollContentBackground(.hidden)
                .frame(width: 300, height: 110)
                .focused($isContentFocused)
                .onKeyPress(phases: .down) { press in
                    switch press.key {
                    case .return where !press.modifiers.contains(.shift):
                        save()
                        return .handled
                    case .escape:
                        onCancel()
                        return .handled
                    default:
                        return .ignored
                    }
                }

            TextField("tags, comma separated", text: $tagsText)
                .textFieldStyle(.plain)
                .font(DotsTypography.footnote)
                .foregroundStyle(DotsColor.Ink.secondary)
                .onSubmit(save)

            HStack {
                DotsMetaLabel("↩ SAVE · ⇧↩ LINE · ESC CANCEL", tint: DotsColor.Ink.muted)
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.plain)
                    .font(DotsTypography.callout)
                    .foregroundStyle(DotsColor.brand)
            }
        }
        .padding(DotsSpacing.md)
        .onAppear {
            isContentFocused = true
            selection = TextSelection(range: content.startIndex..<content.endIndex)
        }
    }

    private func save() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onCancel()
            return
        }
        var seen = Set<String>()
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        onSave(trimmed, tags)
    }
}
