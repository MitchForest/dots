public import ComposableArchitecture2
import DotsDomain
import DotsUI
public import SwiftUI
import UniformTypeIdentifiers

struct HomeScreen: View {
    @AppStorage("blog.dots.appearanceMode") private var appearanceRaw = DotsAppearanceMode.system.rawValue
    @Bindable private var store: StoreOf<Home>
    @Environment(\.colorScheme) private var colorScheme

    @State private var isStreakPresented = false

    init(store: StoreOf<Home>) {
        self.store = store
    }

    var body: some View {
        if let workspaceStore = store.scope(\.workspace, action: \.workspace) {
            WorkspaceScreen(store: workspaceStore)
        } else {
            home
        }
    }

    private var home: some View {
        ZStack {
            DotsColor.Background.primary
                .ignoresSafeArea()
            DotsGridSurface()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DotsSpacing.xl) {
                    header

                    if store.vault == nil {
                        vaultSetup
                    } else {
                        ideasStrip
                        today
                    }
                }
                .padding(DotsSpacing.xxl)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .fileImporter(
            isPresented: $store.isFilePickerPresented,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                store.send(.vaultChosen(url))
            }
        }
        .toolbar { toolbarContent }
        .toolbarBackground(.hidden, for: .windowToolbar)
        // The greeting is the page; the window needs no title here.
        .navigationTitle("")
    }

    // MARK: Native titlebar — Streak · Canvas · Settings · appearance

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        // Text controls carry no glass; icon-only buttons keep the system
        // bubble, each detached via fixed spacers.
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: DotsSpacing.lg) {
                Button {
                    isStreakPresented = true
                } label: {
                    HStack(spacing: DotsSpacing.xs) {
                        Circle()
                            .fill(store.isTodayComplete ? DotsColor.Accent.green : .clear)
                            .strokeBorder(
                                store.isTodayComplete ? DotsColor.Accent.green : DotsColor.Accent.orange,
                                lineWidth: 1.5
                            )
                            .frame(width: 8, height: 8)
                        Text("Streak")
                            .font(DotsTypography.footnote)
                            .foregroundStyle(DotsColor.Ink.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help(store.isTodayComplete ? "Today is done" : "Write today to keep your streak")
                .popover(isPresented: $isStreakPresented, arrowEdge: .bottom) {
                    streakPopover
                }

            }
            .fixedSize()
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItem(placement: .primaryAction) {
            // One settings surface: the gear opens the Settings window
            // (vault, AI, writing goal) instead of its own popover.
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .help("Settings (⌘,)")
        }

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItem(placement: .primaryAction) {
            Button {
                let target: DotsAppearanceMode = colorScheme == .dark ? .light : .dark
                appearanceRaw = target.rawValue
            } label: {
                Image(systemName: colorScheme == .dark ? "sun.max.fill" : "moon.fill")
            }
            .help(colorScheme == .dark ? "Switch to light mode" : "Switch to dark mode")
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.xs) {
            HStack(alignment: .top) {
                Text(store.greeting)
                    .font(DotsTypography.display)
                    .foregroundStyle(DotsColor.Ink.primary)

                Spacer()

            }

            if let user = store.user {
                DotsMetaLabel("SIGNED IN AS \(user.login.uppercased())")
            } else {
                DotsMetaLabel("LOCAL ONLY — SIGN IN LATER TO SYNC")
            }
        }
    }

    private var streakPopover: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.sm) {
            if store.streakLength > 0 {
                Text("\(store.streakLength)-day writing streak")
                    .font(DotsTypography.headline)
                    .foregroundStyle(DotsColor.Ink.primary)
            } else {
                Text("No streak yet")
                    .font(DotsTypography.headline)
                    .foregroundStyle(DotsColor.Ink.primary)
            }

            DotsMetaLabel(
                store.isTodayComplete
                    ? "TODAY IS DONE"
                    : "WRITE TODAY TO KEEP IT ALIVE"
            )

            if !store.contributionIntensities.isEmpty {
                DotsContributionGraph(
                    days: store.contributionIntensities.enumerated().map { index, intensity in
                        DotsContributionGraph.Day(
                            intensity: intensity,
                            isToday: index == store.contributionIntensities.count - 1
                        )
                    }
                )
                .padding(.vertical, DotsSpacing.xs)
            }

            DotsMetaLabel("\(store.dotCount) DOT\(store.dotCount == 1 ? "" : "S") · \(store.draftCount) DRAFT\(store.draftCount == 1 ? "" : "S")")
        }
        .padding(DotsSpacing.lg)
    }

    // MARK: Ideas — the collect half of the product, presented as a place

    private var ideasStrip: some View {
        IdeasStripView(dotCount: store.dotCount) {
            store.send(.openCanvasButtonTapped)
        }
    }

    // MARK: Today

    private var today: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.md) {
            HStack(spacing: DotsSpacing.lg) {
                DotsMetaLabel("TODAY")
                Spacer()
                Button {
                    store.send(.newDraftButtonTapped)
                } label: {
                    Label("New draft", systemImage: "plus")
                        .font(DotsTypography.callout)
                        .frame(minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(DotsColor.brand)
                .keyboardShortcut("n", modifiers: .command)
                .help("Start a new draft (⌘N)")
            }

            if let latest = store.documents.first {
                ContinueWritingCardView(
                    document: latest,
                    onDelete: { store.send(.deleteDocumentTapped(latest)) },
                    onOpen: { store.send(.documentTapped(latest)) },
                    onRename: { newTitle in store.send(.renameSubmitted(latest, newTitle)) },
                    onReveal: { store.send(.revealDocumentTapped(latest)) }
                )
            } else {
                Text("Nothing here yet. Start a draft — the blank page won't stay blank long.")
                    .font(DotsTypography.body)
                    .foregroundStyle(DotsColor.Ink.muted)
                    .padding(.vertical, DotsSpacing.lg)
            }

            if store.documents.count > 1 {
                DotsMetaLabel("EARLIER")
                    .padding(.top, DotsSpacing.sm)

                ForEach(store.documents.dropFirst()) { document in
                    DraftCardView(
                        document: document,
                        onDelete: { store.send(.deleteDocumentTapped(document)) },
                        onOpen: { store.send(.documentTapped(document)) },
                        onRename: { newTitle in store.send(.renameSubmitted(document, newTitle)) },
                        onReveal: { store.send(.revealDocumentTapped(document)) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Vault setup

    private var vaultSetup: some View {
        VStack(alignment: .leading, spacing: DotsSpacing.md) {
            Text("Your vault is where every dot, draft, and post lives — plain markdown, yours forever.")
                .font(DotsTypography.body)
                .foregroundStyle(DotsColor.Ink.secondary)

            DotsHairlineCard(
                title: "Create your vault",
                metaLeading: "~/DOTS",
                action: { store.send(.createVaultButtonTapped) },
                content: {
                    Text("A fresh home for your writing.")
                        .font(DotsTypography.body)
                        .foregroundStyle(DotsColor.Ink.secondary)
                }
            )

            DotsHairlineCard(
                title: "Open an existing folder",
                metaLeading: "CHOOSE…",
                action: { store.send(.openVaultButtonTapped) },
                content: {
                    Text("Point Dots at a vault you already have.")
                        .font(DotsTypography.body)
                        .foregroundStyle(DotsColor.Ink.secondary)
                }
            )
        }
        .frame(maxWidth: 720, alignment: .leading)
    }
}

#Preview {
    HomeScreen(
        store: Store(initialState: Home.State()) {
            Home()
        }
    )
}
