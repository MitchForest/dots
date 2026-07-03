import ComposableArchitecture2
import DotsDomain
import DotsUI
import SwiftUI

/// ⌘P command palette: a solid panel anchored under the toolbar. Empty
/// query shows recent drafts; typing searches the whole vault — drafts,
/// ideas, sources — by content. ↑↓ to choose, Return to open, Esc to
/// dismiss.
struct QuickOpenView: View {
    @Bindable var store: StoreOf<QuickOpen>

    @FocusState private var isFieldFocused: Bool
    @State private var selectedIndex = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .onTapGesture { store.send(.dismissed) }

            panel
                .padding(.top, DotsSpacing.md)
        }
        .onExitCommand { store.send(.dismissed) }
    }

    private var rowCount: Int {
        store.isSearching ? store.hits.count : store.documents.count
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: DotsSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DotsColor.Ink.muted)

                TextField("Search the vault", text: $store.query)
                    .textFieldStyle(.plain)
                    .font(DotsTypography.headline)
                    .fontWeight(.regular)
                    .foregroundStyle(DotsColor.Ink.primary)
                    .focused($isFieldFocused)
                    .onSubmit(openSelected)
                    .onKeyPress(.downArrow) {
                        selectedIndex = min(selectedIndex + 1, max(0, rowCount - 1))
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        selectedIndex = max(selectedIndex - 1, 0)
                        return .handled
                    }
            }
            .padding(.horizontal, DotsSpacing.lg)
            .padding(.vertical, DotsSpacing.md)

            Rectangle()
                .fill(DotsColor.Background.hairline)
                .frame(height: 0.5)

            if store.isSearching {
                hitRows
            } else {
                recentRows
            }
        }
        .frame(width: 560)
        .background(
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.panel, style: .continuous)
                .fill(DotsColor.Background.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DotsRadius.Semantic.panel, style: .continuous)
                .strokeBorder(DotsColor.Background.hairline, lineWidth: 1)
        )
        .dotsElevation(.floating)
        .onAppear {
            isFieldFocused = true
            selectedIndex = 0
        }
        .onChange(of: store.query) {
            selectedIndex = 0
        }
    }

    @ViewBuilder private var recentRows: some View {
        if store.documents.isEmpty {
            emptyNote("No drafts yet.")
        } else {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(store.documents.enumerated()), id: \.element.id) { index, document in
                        QuickOpenRowView(
                            icon: "doc.text",
                            title: document.title,
                            detail: document.modifiedAt.formatted(.relative(presentation: .named)),
                            snippet: nil,
                            isSelected: index == selectedIndex
                        ) {
                            store.send(.documentSelected(document))
                        }
                    }
                }
                .padding(DotsSpacing.xs)
            }
            .frame(maxHeight: 300)
        }
    }

    @ViewBuilder private var hitRows: some View {
        if store.hits.isEmpty {
            emptyNote("Nothing matches.")
        } else {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(store.hits.enumerated()), id: \.element.id) { index, hit in
                        QuickOpenRowView(
                            icon: icon(for: hit),
                            title: hit.title,
                            detail: kindLabel(for: hit),
                            snippet: hit.snippet.isEmpty ? nil : hit.snippet,
                            isSelected: index == selectedIndex
                        ) {
                            store.send(.hitSelected(hit))
                        }
                    }
                }
                .padding(DotsSpacing.xs)
            }
            .frame(maxHeight: 340)
        }
    }

    private func emptyNote(_ message: String) -> some View {
        Text(message)
            .font(DotsTypography.footnote)
            .foregroundStyle(DotsColor.Ink.muted)
            .padding(DotsSpacing.lg)
    }

    private func icon(for hit: VaultSearchHit) -> String {
        switch hit {
        case .draft: "doc.text"
        case .idea: "circle.fill"
        case .source: "book"
        }
    }

    private func kindLabel(for hit: VaultSearchHit) -> String {
        switch hit {
        case .draft: "Draft"
        case .idea: "Idea"
        case .source: "Source"
        }
    }

    private func openSelected() {
        if store.isSearching {
            guard !store.hits.isEmpty else { return }
            store.send(.hitSelected(store.hits[min(selectedIndex, store.hits.count - 1)]))
        } else {
            guard !store.documents.isEmpty else { return }
            store.send(.documentSelected(store.documents[min(selectedIndex, store.documents.count - 1)]))
        }
    }
}

private struct QuickOpenRowView: View {
    let icon: String
    let title: String
    let detail: String
    let snippet: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: DotsSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DotsColor.Ink.muted)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DotsTypography.body)
                        .foregroundStyle(DotsColor.Ink.primary)
                        .lineLimit(1)
                    if let snippet {
                        Text(snippet)
                            .font(DotsTypography.footnote)
                            .foregroundStyle(DotsColor.Ink.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(detail)
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Ink.muted)
            }
            .padding(.horizontal, DotsSpacing.md)
            .padding(.vertical, DotsSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DotsRadius.sm, style: .continuous)
                    .fill(isSelected || isHovered ? DotsColor.Surface.pressed : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
