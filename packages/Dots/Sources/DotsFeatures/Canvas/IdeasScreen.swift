public import ComposableArchitecture2
import DotsDomain
import DotsEngine
import DotsUI
import SwiftUI

/// The idea workspace. Full layout is the Apple-Notes shape — folders ·
/// Sources/Ideas list · detail — with the canvas as a view toggle on the
/// Ideas tab. Compact layout (the writing side panel) drops the folder
/// column and detail pane.
struct IdeasScreen: View {
    enum Layout {
        case compact
        case full
    }

    @Bindable private var store: StoreOf<Ideas>
    private let layout: Layout

    @State private var dragTranslation: CGSize = .zero
    @State private var draggingID: Dot.ID?
    @State private var expandedID: Dot.ID?
    @State private var filterQuery = ""
    @State private var hasFitOnLoad = false
    @State private var isCapturePresented = false
    @State private var linkSource: Dot.ID?
    @State private var linkPoint: CGPoint?

    private static let canvasExtent: CGFloat = 6000

    init(store: StoreOf<Ideas>, layout: Layout = .full) {
        self.store = store
        self.layout = layout
    }

    var body: some View {
        Group {
            if layout == .full {
                fullBody
            } else {
                compactBody
            }
        }
        .background(DotsColor.Background.primary)
        .onChange(of: store.openSourceID) { _, id in
            if id != nil {
                isCapturePresented = false
            }
        }
    }

    // MARK: Layouts

    private var fullBody: some View {
        HStack(spacing: 0) {
            FolderColumnView(
                folders: store.folders,
                selection: $store.folderSelection,
                onCreateFolder: { store.send(.createFolderSubmitted($0)) }
            )
            hairline

            if store.tab == .ideas, store.isCanvasView {
                canvasPane
            } else {
                listColumn
                    .frame(width: 320)
                hairline
                detailPane
            }
        }
    }

    private var compactBody: some View {
        Group {
            if store.tab == .sources, let source = store.openSource {
                SourceReaderView(
                    source: source,
                    extractedCount: extractedCount(from: source),
                    onClose: { $store.openSourceID.wrappedValue = nil },
                    onDelete: { store.send(.deleteSourceTapped(source.id)) },
                    onDistill: { content, tags in
                        store.send(.distillSubmitted(source, content: content, tags: tags))
                    },
                    onExtract: { excerpt in
                        store.send(.extractSelectionTapped(source, excerpt: excerpt))
                    }
                )
            } else if store.tab == .ideas, store.isCanvasView {
                canvasPane
            } else {
                listColumn
            }
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(DotsColor.Background.hairline)
            .frame(width: 1)
    }

    // MARK: List column

    private var listColumn: some View {
        VStack(spacing: 0) {
            listHeader
                .padding(DotsSpacing.md)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: DotsSpacing.xs) {
                    if store.tab == .ideas {
                        ideaRows
                    } else {
                        sourceRows
                    }
                }
                .padding(.horizontal, DotsSpacing.md)
                .padding(.bottom, DotsSpacing.xl)
            }
        }
    }

    /// One context-sensitive +: on Ideas it thinks up a new idea, on
    /// Sources it saves a source. The tab you're on decides what "add" means.
    private var listHeader: some View {
        HStack(spacing: DotsSpacing.sm) {
            tabToggle

            Spacer(minLength: 0)

            if store.tab == .ideas {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        $store.isCanvasView.wrappedValue.toggle()
                    }
                } label: {
                    Image(systemName: store.isCanvasView ? "list.bullet" : "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(store.isCanvasView ? DotsColor.brand : DotsColor.Ink.secondary)
                        .padding(DotsSpacing.xs)
                        .background(Capsule().fill(.regularMaterial))
                }
                .buttonStyle(.plain)
                .help(store.isCanvasView ? "Back to the list" : "See connections on the canvas")

                Button {
                    store.send(.newDotButtonTapped)
                } label: {
                    plusLabel
                }
                .buttonStyle(.plain)
                .keyboardShortcut("d", modifiers: .command)
                .help("New idea (⌘D)")
            } else {
                captureButton
            }
        }
    }

    private var plusLabel: some View {
        Image(systemName: "plus")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DotsColor.Ink.secondary)
            .padding(DotsSpacing.xs)
            .background(Capsule().fill(.regularMaterial))
    }

    private var captureButton: some View {
        Button {
            isCapturePresented = true
        } label: {
            plusLabel
        }
        .buttonStyle(.plain)
        .keyboardShortcut("d", modifiers: .command)
        .help("Save a source — paste a link or text (⌘D)")
        .popover(isPresented: $isCapturePresented, arrowEdge: .bottom) {
            SourceCaptureView(
                error: store.captureError,
                isCapturing: store.isCapturingSource,
                onSubmitText: { title, text in
                    store.send(.sourceTextSubmitted(title: title, text: text))
                },
                onSubmitURL: { store.send(.sourceURLSubmitted($0)) }
            )
        }
    }

    private var tabToggle: some View {
        HStack(spacing: 2) {
            tabButton("Ideas", tab: .ideas)
            tabButton("Sources", tab: .sources)
        }
        .padding(2)
        .background(Capsule().fill(.regularMaterial))
    }

    private func tabButton(_ title: String, tab: Ideas.Tab) -> some View {
        let isActive = store.tab == tab
        return Button {
            $store.tab.wrappedValue = tab
        } label: {
            Text(title)
                .font(DotsTypography.footnote)
                .foregroundStyle(isActive ? DotsColor.Ink.inverse : DotsColor.Ink.secondary)
                .padding(.horizontal, DotsSpacing.sm)
                .padding(.vertical, 3)
                .background(Capsule().fill(isActive ? DotsColor.Ink.primary : .clear))
                .frame(minHeight: 24)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var ideaRows: some View {
        let visible = filteredDots
        let pending = filteredPendingIdeas
        // Drafted ideas ride on top of the list, visibly provisional,
        // until each earns its accept (becoming a real row below) or is
        // discarded.
        ForEach(pending) { row in
            PendingIdeaRowView(
                pending: row,
                isSelected: store.pendingSelection.contains(row.id),
                onAccept: { store.send(.proposedIdeaAccepted(row.proposalId, row.idea.id)) },
                onDiscard: { store.send(.proposedIdeaDiscarded(row.proposalId, row.idea.id)) },
                onTap: {
                    store.send(.pendingIdeaTapped(row.id, modifier: DotListRowView.selectionModifier()))
                }
            )
            .contextMenu {
                pendingMenu(for: row)
            }
        }
        ForEach(visible) { dot in
            // Compact has no detail pane, so the row itself opens: the
            // sidebar accordion.
            if layout == .compact, expandedID == dot.id {
                IdeaExpandedRowView(
                    dot: dot,
                    folders: store.folders,
                    selectionContext: selectionContext,
                    onCollapse: { withAnimation(.easeInOut(duration: 0.15)) { expandedID = nil } },
                    onDelete: { store.send(.deleteDotTapped(dot.id)) },
                    onEdit: { content, tags in
                        store.send(.dotEdited(dot.id, content: content, tags: tags))
                    },
                    onMove: { folder in store.send(.dotMoved(dot.id, folder: folder)) }
                )
            } else {
                DotListRowView(
                    dot: dot,
                    folders: store.folders,
                    isConnectedToSelection: idsConnectedToSelection.contains(dot.id),
                    isSelected: store.selection.contains(dot.id),
                    selectionContext: selectionContext,
                    onDelete: { store.send(.deleteDotTapped(dot.id)) },
                    onMove: { folder in store.send(.dotMoved(dot.id, folder: folder)) },
                    onTap: { modifier in
                        store.send(.dotTapped(dot.id, modifier: modifier))
                        if layout == .compact, modifier == .none {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                expandedID = dot.id
                            }
                        }
                    }
                )
            }
        }
        if visible.isEmpty, pending.isEmpty {
            Text(store.dots.isEmpty ? "No ideas yet — press + to think one up." : "Nothing here.")
                .font(DotsTypography.footnote)
                .foregroundStyle(DotsColor.Ink.muted)
                .padding(DotsSpacing.xl)
        }
    }

    @ViewBuilder private var sourceRows: some View {
        let visible = store.visibleSources
        ForEach(visible) { source in
            SourceRowView(
                source: source,
                folders: store.folders,
                isSelected: store.openSourceID == source.id
                    || store.sourceSelection.contains(source.id),
                onDelete: { store.send(.deleteSourceTapped(source.id)) },
                onDeleteSelection: { store.send(.deleteSourceSelectionTapped) },
                onMove: { folder in store.send(.sourceMoved(source.id, folder: folder)) },
                onOpen: {
                    store.send(.sourceTapped(source.id, modifier: DotListRowView.selectionModifier()))
                },
                selectionCount: store.sourceSelection.contains(source.id)
                    ? store.sourceSelection.count
                    : 1
            )
        }
        if visible.isEmpty {
            Text("No sources yet — paste a link with the capture button above.")
                .font(DotsTypography.footnote)
                .foregroundStyle(DotsColor.Ink.muted)
                .padding(DotsSpacing.xl)
        }
    }

    // MARK: Detail pane (full layout)

    private func referenceItem(for reference: Reference) -> IdeaDetailView.ReferenceItem {
        if let idea = store.state.dot(for: reference) {
            return IdeaDetailView.ReferenceItem(
                reference: reference,
                title: DotPreview.title(idea.content),
                isSource: false
            )
        }
        if let source = store.state.source(for: reference) {
            return IdeaDetailView.ReferenceItem(
                reference: reference,
                title: source.title,
                isSource: true
            )
        }
        return IdeaDetailView.ReferenceItem(
            reference: reference,
            title: reference.rawValue,
            isSource: false
        )
    }

    /// Reference navigation: an idea focuses it in the Ideas tab; a source
    /// opens its reader in the Sources tab.
    private func open(item: IdeaDetailView.ReferenceItem) {
        if item.isSource {
            $store.tab.wrappedValue = .sources
            $store.openSourceID.wrappedValue = Source.ID(item.reference.rawValue)
        } else {
            $store.tab.wrappedValue = .ideas
            store.send(.dotTapped(Dot.ID(item.reference.rawValue), modifier: .none))
        }
    }

    private func extractedCount(from source: Source) -> Int {
        store.dots.count {
            $0.source?.ref == source.id || $0.references.contains(Reference(source.id))
        }
    }
}

// MARK: - Canvas view (the reference graph, spatially)

extension IdeasScreen {
    private var canvasPane: some View {
        GeometryReader { proxy in
            ZStack {
                ZoomPanCanvas(
                    viewport: $store.viewport,
                    isLocked: store.isLocked,
                    onDoubleClick: { store.send(.canvasDoubleClicked($0)) },
                    underlay: { viewport in connectionLayer(viewport: viewport) },
                    content: { canvasContent }
                )

                canvasTopControls
                floatingControls(paneSize: proxy.size)
            }
            .onChange(of: store.dots.isEmpty, initial: true) { _, isEmpty in
                guard !hasFitOnLoad, !isEmpty else { return }
                hasFitOnLoad = true
                fitToContent(paneSize: proxy.size)
            }
        }
    }

    /// Pane chrome for the canvas: a way back to the list, and capture.
    private var canvasTopControls: some View {
        VStack {
            HStack(spacing: DotsSpacing.sm) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        $store.isCanvasView.wrappedValue = false
                    }
                } label: {
                    HStack(spacing: DotsSpacing.xs) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 11, weight: .medium))
                        Text("List")
                            .font(DotsTypography.footnote)
                    }
                    .foregroundStyle(DotsColor.Ink.secondary)
                    .padding(.horizontal, DotsSpacing.sm)
                    .padding(.vertical, DotsSpacing.xs)
                    .background(Capsule().fill(.regularMaterial))
                }
                .buttonStyle(.plain)
                .help("Back to the list")

                Spacer()
            }
            .padding(DotsSpacing.md)
            Spacer()
        }
    }

    private var canvasContent: some View {
        let positions = store.positions
        return ZStack(alignment: .topLeading) {
            ForEach(store.visibleDots) { dot in
                DotCardView(
                    dot: dot,
                    isSelected: store.selection.contains(dot.id),
                    selectionContext: selectionContext,
                    startsEditing: store.freshDotID == dot.id,
                    onConnectDragChanged: { point in
                        linkSource = dot.id
                        linkPoint = point
                    },
                    onConnectDragEnded: { point in
                        defer {
                            linkSource = nil
                            linkPoint = nil
                        }
                        if let target = hitTest(point: point, positions: positions, excluding: dot.id) {
                            store.send(.dotsConnected(dot.id, target))
                        }
                    },
                    onDelete: { store.send(.deleteDotTapped(dot.id)) },
                    onDragChanged: { translation in
                        draggingID = dot.id
                        dragTranslation = translation
                    },
                    onDragEnded: { translation in
                        draggingID = nil
                        dragTranslation = .zero
                        var point = positions[dot.id] ?? .zero
                        point.x += translation.width
                        point.y += translation.height
                        store.send(.dotDragEnded(dot.id, point))
                    },
                    onEdit: { content, tags in
                        store.send(.dotEdited(dot.id, content: content, tags: tags))
                    },
                    onTap: { modifier in
                        store.send(.dotTapped(dot.id, modifier: modifier))
                    }
                )
                .position(displayPosition(for: dot.id, positions: positions))
            }
        }
        .frame(width: Self.canvasExtent, height: Self.canvasExtent, alignment: .topLeading)
        .coordinateSpace(name: CanvasSpace.name)
    }

    private func connectionLayer(viewport: CanvasViewportState) -> some View {
        let positions = store.positions
        var display: [Dot.ID: CGPoint] = [:]
        for dot in store.visibleDots {
            display[dot.id] = displayPosition(for: dot.id, positions: positions)
        }
        return CanvasConnectionsView(
            dots: store.visibleDots,
            displayPositions: display,
            selection: store.selection,
            linkDraft: linkSource.flatMap { source in
                linkPoint.map { (source: source, point: $0) }
            },
            viewport: viewport
        )
    }

    private func hitTest(
        point: CGPoint,
        positions: [Dot.ID: CGPoint],
        excluding: Dot.ID
    ) -> Dot.ID? {
        let halfWidth = DotCardView.cardSize.width / 2 + 12
        let halfHeight = DotCardView.cardSize.height / 2 + 12
        return store.visibleDots.first { dot in
            guard dot.id != excluding, let center = positions[dot.id] else { return false }
            return abs(point.x - center.x) <= halfWidth && abs(point.y - center.y) <= halfHeight
        }?.id
    }

    private func displayPosition(for id: Dot.ID, positions: [Dot.ID: CGPoint]) -> CGPoint {
        var point = positions[id] ?? .zero
        if draggingID == id {
            point.x += dragTranslation.width
            point.y += dragTranslation.height
        }
        return point
    }

    private var contentBounds: CGRect {
        let positions = store.positions
        var bounds = CGRect.null
        for dot in store.visibleDots {
            guard let center = positions[dot.id] else { continue }
            bounds = bounds.union(
                CGRect(
                    x: center.x - DotCardView.cardSize.width / 2,
                    y: center.y - DotCardView.cardSize.height / 2,
                    width: DotCardView.cardSize.width,
                    height: DotCardView.cardSize.height
                )
            )
        }
        return bounds
    }

    private func fitToContent(paneSize: CGSize) {
        var viewport = store.viewport
        viewport.fit(bounds: contentBounds, in: paneSize)
        withAnimation(.easeInOut(duration: 0.35)) {
            $store.viewport.wrappedValue = viewport
        }
    }

    private func floatingControls(paneSize: CGSize) -> some View {
        CanvasBottomBarView(
            dotCount: store.visibleDots.count,
            showsViewportControls: true,
            isLocked: $store.isLocked,
            zoomPercent: Int(store.viewport.zoomScale * 100),
            onFit: { fitToContent(paneSize: paneSize) },
            onNewDot: { store.send(.newDotButtonTapped) },
            onZoomIn: { setZoom(store.viewport.zoomScale * 1.25, paneSize: paneSize) },
            onZoomOut: { setZoom(store.viewport.zoomScale / 1.25, paneSize: paneSize) }
        )
    }

    private func setZoom(_ zoom: CGFloat, paneSize: CGSize) {
        let clamped = min(CanvasViewportState.maximumZoomScale, max(CanvasViewportState.minimumZoomScale, zoom))
        let center = CGPoint(x: paneSize.width / 2, y: paneSize.height / 2)
        var viewport = store.viewport
        let anchor = viewport.canvasPoint(fromViewportPoint: center)
        viewport.zoomScale = clamped
        viewport.contentOffset = CGPoint(
            x: anchor.x - center.x / clamped,
            y: anchor.y - center.y / clamped
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            $store.viewport.wrappedValue = viewport
        }
    }
}

// MARK: - Selection context

extension IdeasScreen {
    private var selectionContext: DotSelectionContext {
        DotSelectionContext(
            isSelectionFullyConnected: store.isSelectionFullyConnected,
            selectedIDs: store.selection,
            // The compact panel lives beside an open draft by construction.
            sendsToOpenDraft: layout == .compact,
            onConnectSelection: { store.send(.connectSelectionTapped) },
            onDeleteSelection: { store.send(.deleteSelectionTapped) },
            onDisconnectSelection: { store.send(.disconnectSelectionTapped) },
            onDraftFromSelection: { store.send(.draftFromSelectionTapped) },
            onDraftFromDot: { dot in
                store.send(.dotTapped(dot.id, modifier: .none))
                store.send(.draftFromSelectionTapped)
            },
            onSynthesizeSelection: { store.send(.synthesizeSelectionTapped) }
        )
    }

    /// Ideas referenced by / referencing the current selection, excluding
    /// the selection itself — powers the list's connectivity accents.
    private var idsConnectedToSelection: Set<Dot.ID> {
        let selected = Set(store.selection)
        guard !selected.isEmpty else { return [] }
        var connected = Set<Dot.ID>()
        for dot in store.dots {
            if selected.contains(dot.id) {
                connected.formUnion(dot.references.map { Dot.ID($0.rawValue) })
            } else if dot.references.contains(where: { selected.contains(Dot.ID($0.rawValue)) }) {
                connected.insert(dot.id)
            }
        }
        connected.subtract(selected)
        return connected
    }
}

#Preview {
    IdeasScreen(
        store: Store(initialState: Ideas.State(vault: URL(filePath: "/mock/vault"))) {
            Ideas()
        }
    )
    .frame(width: 1100, height: 640)
}

// MARK: - Proposal review rows

extension IdeasScreen {
    /// Right-click acts on the selection when the row is part of it —
    /// otherwise on just that row (Finder's retargeting rule).
    @ViewBuilder fileprivate func pendingMenu(for row: Ideas.PendingIdea) -> some View {
        let selected = store.pendingSelection.contains(row.id)
            ? store.pendingSelection.count
            : 1
        let noun = selected == 1 ? "draft" : "\(selected) drafts"
        Button {
            if selected > 1 {
                store.send(.pendingSelectionAccepted)
            } else {
                store.send(.proposedIdeaAccepted(row.proposalId, row.idea.id))
            }
        } label: {
            Label("Accept \(noun)", systemImage: "checkmark")
        }
        Button(role: .destructive) {
            if selected > 1 {
                store.send(.pendingSelectionDiscarded)
            } else {
                store.send(.proposedIdeaDiscarded(row.proposalId, row.idea.id))
            }
        } label: {
            Label("Discard \(noun)", systemImage: "xmark")
        }
    }

    @ViewBuilder private var detailPane: some View {
        if store.tab == .sources {
            if let source = store.openSource {
                SourceReaderView(
                    source: source,
                    extractedCount: extractedCount(from: source),
                    onClose: { $store.openSourceID.wrappedValue = nil },
                    onDelete: { store.send(.deleteSourceTapped(source.id)) },
                    onDistill: { content, tags in
                        store.send(.distillSubmitted(source, content: content, tags: tags))
                    },
                    onExtract: { excerpt in
                        store.send(.extractSelectionTapped(source, excerpt: excerpt))
                    }
                )
            } else {
                detailPlaceholder("Select a source to read it.")
            }
        } else if let pending = store.focusedPendingIdea {
            PendingIdeaDetailView(
                pending: pending,
                onAccept: { store.send(.proposedIdeaAccepted(pending.proposalId, pending.idea.id)) },
                onDiscard: { store.send(.proposedIdeaDiscarded(pending.proposalId, pending.idea.id)) }
            )
        } else if let dot = store.focusedDot {
            IdeaDetailView(
                dot: dot,
                backlinks: store.state.backlinks(of: dot.id).map { backlink in
                    IdeaDetailView.ReferenceItem(
                        reference: Reference(backlink.id),
                        title: DotPreview.title(backlink.content),
                        isSource: false
                    )
                },
                references: dot.references.map(referenceItem(for:)),
                sourceTitle: dot.source?.ref.flatMap { ref in
                    store.sources.first { $0.id == ref }?.title
                },
                onEdit: { content, tags in
                    store.send(.dotEdited(dot.id, content: content, tags: tags))
                },
                onMakeMine: { store.send(.makeMineTapped(dot.id)) },
                onOpen: open(item:),
                onRemoveReference: { store.send(.referenceRemoved(dot.id, $0)) }
            )
        } else {
            detailPlaceholder("Select an idea — or press + to think one up.")
        }
    }

    private func detailPlaceholder(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(DotsTypography.body)
                .foregroundStyle(DotsColor.Ink.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var filteredDots: [Dot] {
        let query = filterQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.visibleDots }
        return store.visibleDots.filter { dot in
            dot.content.localizedCaseInsensitiveContains(query)
                || dot.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var filteredPendingIdeas: [Ideas.PendingIdea] {
        let query = filterQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.visiblePendingIdeas }
        return store.visiblePendingIdeas.filter {
            $0.idea.text.localizedCaseInsensitiveContains(query)
        }
    }
}
