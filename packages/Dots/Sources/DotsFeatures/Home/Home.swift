public import ComposableArchitecture2
public import DotsDomain
import Dependencies
import DotsClients
import DotsEngine
public import Foundation

@Feature
public struct Home {
    public struct State: Equatable {
        public var contributionIntensities: [Double] = []
        public var documents: [VaultDocument] = []
        public var dotCount = 0
        public var draftCount = 0
        public var greeting = ""
        public var intake = Intake.State()
        public var isFilePickerPresented = false
        public var isTodayComplete = false
        public var stats: VaultStats?
        public var streakGoal = StreakGoal()
        public var streakLength = 0
        public var user: GitHubUser?
        public var vault: URL?
        public var workspace: Workspace.State?

        public init(user: GitHubUser? = nil) {
            self.user = user
        }
    }

    public enum Action {
        case createVaultButtonTapped
        case deleteDocumentTapped(VaultDocument)
        case documentTapped(VaultDocument)
        case documentsLoaded([VaultDocument])
        case draftCreated(VaultDocument)
        case intake(Intake.Action)
        case newDraftButtonTapped
        case openCanvasButtonTapped
        case openVaultButtonTapped
        case renameSubmitted(VaultDocument, String)
        case revealDocumentTapped(VaultDocument)
        case settingsLoaded(StreakGoal)
        case statsLoaded(VaultStats)
        case vaultChosen(URL)
        case vaultLoaded(URL?)
        case workspace(Workspace.Action)
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    @Dependency(\.vaultClient) var vaultClient

    public init() {}

    public var body: some Feature {
        Features {
            Scope(\.intake, action: \.intake) {
                Intake()
            }

            updates
        }
    }

    private var updates: some Feature {
        Update { state, action in
            switch action {
            case .createVaultButtonTapped:
                store.addTask {
                    let location = Self.defaultVaultLocation
                    try await vaultClient.createVault(location)
                    try store.send(.vaultLoaded(location))
                }

            case .deleteDocumentTapped(let document):
                guard let vault = state.vault else { break }
                store.addTask {
                    try await vaultClient.deleteDocument(document.url)
                    try store.send(.documentsLoaded(await vaultClient.recentDocuments(vault)))
                }

            case .documentTapped(let document):
                guard let vault = state.vault else { break }
                state.workspace = Workspace.State(vault: vault, documentURL: document.url)

            case .documentsLoaded(let documents):
                state.documents = documents
                guard let vault = state.vault else { break }
                store.addTask {
                    let stats = try await vaultClient.vaultStats(vault)
                    try store.send(.statsLoaded(stats))
                }

            case .draftCreated(let document):
                guard let vault = state.vault else { break }
                state.workspace = Workspace.State(vault: vault, documentURL: document.url)

            case .intake:
                break

            case .openCanvasButtonTapped:
                guard let vault = state.vault else { break }
                state.workspace = Workspace.State(vault: vault)

            case .openVaultButtonTapped:
                state.isFilePickerPresented = true

            case .newDraftButtonTapped:
                guard let vault = state.vault else { break }
                store.addTask {
                    let document = try await vaultClient.createDraft(vault, "Untitled")
                    try store.send(.draftCreated(document))
                }

            case .renameSubmitted(let document, let newTitle):
                guard let vault = state.vault else { break }
                store.addTask {
                    _ = try await vaultClient.renameDocument(document.url, newTitle)
                    try store.send(.documentsLoaded(await vaultClient.recentDocuments(vault)))
                }

            case .revealDocumentTapped(let document):
                store.addTask {
                    await vaultClient.revealDocument(document.url)
                }

            case .settingsLoaded(let goal):
                state.streakGoal = goal
                guard let vault = state.vault else { break }
                store.addTask {
                    let documents = try await vaultClient.recentDocuments(vault)
                    try store.send(.documentsLoaded(documents))
                }

            case .statsLoaded(let stats):
                state.stats = stats
                recomputeStreak(state: &state)

            case .vaultChosen(let location):
                store.addTask {
                    try await vaultClient.openVault(location)
                    try store.send(.vaultLoaded(location))
                }

            case .workspace:
                break

            case .vaultLoaded(let location):
                state.vault = location
                guard let location else { break }
                store.addTask {
                    let goal = try await vaultClient.readStreakGoal(location)
                    try store.send(.settingsLoaded(goal))
                }
                // Browser captures arrive from outside this process; keep
                // the counts and recents honest when they land.
                store.addTask {
                    for await _ in vaultClient.captureEvents() {
                        try store.send(.documentsLoaded(await vaultClient.recentDocuments(location)))
                        let stats = try await vaultClient.vaultStats(location)
                        try store.send(.statsLoaded(stats))
                    }
                }
            }
        }
        .onMount { state in
            state.greeting = Greeting.text(at: now, calendar: calendar)
            store.addTask {
                let stored = await vaultClient.storedVaultLocation()
                try store.send(.vaultLoaded(stored))
            }
            // Settings live in their own window (and settings.json can be
            // edited from another device): re-run the load chain when the
            // goal changes or the vault is switched.
            store.addTask {
                for await _ in vaultClient.settingsEvents() {
                    try store.send(.vaultLoaded(await vaultClient.storedVaultLocation()))
                }
            }
        }
        .ifLet(\.workspace, action: \.workspace) {
            Workspace()
        }
        .onEvent(WorkspaceClosed.self) { _, state in
            state.workspace = nil
            guard let vault = state.vault else { return }
            store.addTask {
                let documents = try await vaultClient.recentDocuments(vault)
                try store.send(.documentsLoaded(documents))
            }
        }
    }

    private static var defaultVaultLocation: URL {
        URL(filePath: NSHomeDirectory(), directoryHint: .isDirectory)
            .appending(path: "Dots")
    }

    private func recomputeStreak(state: inout State) {
        guard let stats = state.stats else { return }
        state.dotCount = stats.dotCount
        state.draftCount = stats.draftCount
        state.contributionIntensities = WritingActivity.intensities(
            byDay: stats.activityByDay.merging(stats.wordsByDay) { activity, _ in activity },
            today: now,
            calendar: calendar
        )
        state.isTodayComplete = WritingActivity.isComplete(
            on: now,
            stats: stats,
            goal: state.streakGoal,
            calendar: calendar
        )
        state.streakLength = WritingActivity.streak(
            stats: stats,
            goal: state.streakGoal,
            today: now,
            calendar: calendar
        )
    }
}
