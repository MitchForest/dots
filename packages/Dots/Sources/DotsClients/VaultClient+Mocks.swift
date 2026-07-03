public import DotsDomain
public import Foundation
import DotsEngine

// MARK: - Mocks & dependency registration

extension VaultClient {
    // periphery:ignore - test support; SPM test targets sit outside this scan
    /// In-memory fixture for previews and tests.
    public static func inMemory(
        location: URL? = nil,
        documents: [VaultDocument] = [],
        dots: [Dot] = [],
        sources: [Source] = [],
        folders: [String] = [],
        proposals: [IdeaProposal] = []
    ) -> Self {
        let store = InMemoryVault(
            location: location,
            documents: documents,
            dots: dots,
            sources: sources,
            folders: folders,
            proposals: proposals
        )
        var client = Self()
        client.createDot = { _, seed in await store.createDot(seed: seed) }
        client.createDraft = { _, title in await store.createDraft(title: title) }
        client.createDraftFromDots = { _, _ in await store.createDraft(title: "Untitled") }
        client.createFolder = { _, name in await store.createFolder(name: name) }
        client.createProposal = { _, sourceId, ideas in
            await store.createProposal(sourceId: sourceId, ideas: ideas)
        }
        client.createSource = { _, seed in await store.createSource(seed: seed) }
        client.createVault = { location in await store.setLocation(location) }
        client.deleteDocument = { url in await store.deleteDocument(at: url) }
        client.deleteDot = { _, id in await store.deleteDot(id: id) }
        client.deleteSource = { _, id in await store.deleteSource(id: id) }
        client.documentChanges = { _ in AsyncStream { _ in } }
        client.forgetVault = { await store.setLocation(nil) }
        client.listDots = { _ in await store.allDots() }
        client.listFolders = { _ in await store.allFolders() }
        client.listProposals = { _ in await store.allProposals() }
        client.listSources = { _ in await store.allSources() }
        client.moveDot = { _, id, folder in await store.moveDot(id: id, folder: folder) }
        client.moveSource = { _, id, folder in await store.moveSource(id: id, folder: folder) }
        client.openVault = { location in await store.setLocation(location) }
        client.readArrangement = { _ in await store.currentArrangement() }
        client.readDocument = { url in await store.contents(at: url) }
        client.readIntakeEnabled = { _ in await store.currentIntakeEnabled() }
        client.readStreakGoal = { _ in await store.currentStreakGoal() }
        client.recordWordsWritten = { _, words in await store.recordWords(words) }
        client.recentDocuments = { _ in await store.documents() }
        client.renameDocument = { url, newTitle in await store.renameDocument(at: url, to: newTitle) }
        client.searchVault = { _, query in
            var drafts: [(document: VaultDocument, content: String)] = []
            for document in await store.documents() {
                drafts.append((document, await store.contents(at: document.url)))
            }
            return VaultSearch.rank(
                query: query,
                drafts: drafts,
                dots: await store.allDots(),
                sources: await store.allSources()
            )
        }
        client.storedVaultLocation = { await store.currentLocation() }
        client.updateDot = { _, dot in await store.updateDot(dot) }
        client.updateProposal = { _, proposal in await store.updateProposal(proposal) }
        client.vaultStats = { _ in await store.stats() }
        client.writeArrangement = { _, arrangement in await store.setArrangement(arrangement) }
        client.writeDocument = { url, contents in await store.setContents(contents, at: url) }
        client.writeIntakeEnabled = { _, isEnabled in await store.setIntakeEnabled(isEnabled) }
        client.writeStreakGoal = { _, goal in await store.setStreakGoal(goal) }
        return client
    }

    /// Fails every call — the default test value so unstubbed access is loud.
    public static var unavailable: Self { Self() }
}

private actor InMemoryVault {
    private var arrangement = CanvasArrangement()
    private var isIntakeEnabled = true
    private var folders: [String]
    private var location: URL?
    private var recordedWords = 0
    private var streakGoal = StreakGoal()
    private var storedContents: [URL: String] = [:]
    private var storedDocuments: [VaultDocument]
    private var storedDots: [Dot]
    private var storedProposals: [IdeaProposal]
    private var storedSources: [Source]

    init(
        location: URL?,
        documents: [VaultDocument],
        dots: [Dot],
        sources: [Source],
        folders: [String],
        proposals: [IdeaProposal] = []
    ) {
        self.folders = folders
        self.location = location
        self.storedDocuments = documents
        self.storedDots = dots
        self.storedProposals = proposals
        self.storedSources = sources
    }

    func allDots() -> [Dot] { storedDots }

    func currentIntakeEnabled() -> Bool { isIntakeEnabled }

    func setIntakeEnabled(_ isEnabled: Bool) {
        isIntakeEnabled = isEnabled
    }

    func allFolders() -> [String] { folders }

    func allProposals() -> [IdeaProposal] { storedProposals }

    func allSources() -> [Source] { storedSources }

    func contents(at url: URL) -> String {
        storedContents[url] ?? ""
    }

    func createDot(seed: DotSeed) -> Dot {
        let dot = Dot(
            id: Dot.ID(String(format: "mockdot-%03d", storedDots.count)),
            content: seed.content,
            capturedAt: Date(timeIntervalSince1970: TimeInterval(storedDots.count)),
            source: seed.source,
            references: seed.references,
            tags: seed.tags,
            folder: seed.folder
        )
        storedDots.insert(dot, at: 0)
        return dot
    }

    func createFolder(name: String) {
        if !folders.contains(name) {
            folders.append(name)
            folders.sort()
        }
    }

    func createProposal(sourceId: Source.ID, ideas: [String]) -> IdeaProposal {
        let proposal = IdeaProposal(
            id: IdeaProposal.ID(String(format: "mockproposal-%03d", storedProposals.count)),
            sourceId: sourceId,
            ideas: ideas.enumerated().map { ProposedIdea(id: $0.offset + 1, text: $0.element) },
            createdAt: Date(timeIntervalSince1970: TimeInterval(storedProposals.count))
        )
        storedProposals.insert(proposal, at: 0)
        return proposal
    }

    func createSource(seed: SourceSeed) -> Source {
        let source = Source(
            id: Source.ID(String(format: "mocksource-%03d", storedSources.count)),
            title: seed.title,
            content: seed.content,
            capturedAt: Date(timeIntervalSince1970: TimeInterval(storedSources.count)),
            url: seed.url,
            author: seed.author,
            site: seed.site,
            folder: seed.folder
        )
        storedSources.insert(source, at: 0)
        return source
    }

    func updateProposal(_ proposal: IdeaProposal) {
        storedProposals = storedProposals.map { $0.id == proposal.id ? proposal : $0 }
    }

    func moveDot(id: Dot.ID, folder: String?) {
        storedDots = storedDots.map { dot in
            guard dot.id == id else { return dot }
            var moved = dot
            moved.folder = folder
            return moved
        }
    }

    func moveSource(id: Source.ID, folder: String?) {
        storedSources = storedSources.map { source in
            guard source.id == id else { return source }
            var moved = source
            moved.folder = folder
            return moved
        }
    }

    func createDraft(title: String) -> VaultDocument {
        let document = VaultDocument(
            url: URL(filePath: "/mock/drafts/\(DraftTemplate.slug(fromTitle: title)).md"),
            title: title,
            modifiedAt: Date(timeIntervalSince1970: 0)
        )
        storedDocuments.insert(document, at: 0)
        return document
    }

    func currentArrangement() -> CanvasArrangement { arrangement }

    func currentLocation() -> URL? { location }

    func deleteDocument(at url: URL) {
        storedDocuments.removeAll { $0.url == url }
    }

    func deleteDot(id: Dot.ID) {
        storedDots.removeAll { $0.id == id }
    }

    func deleteSource(id: Source.ID) {
        storedSources.removeAll { $0.id == id }
    }

    func documents() -> [VaultDocument] { storedDocuments }

    func renameDocument(at url: URL, to newTitle: String) -> URL {
        let destination = url.deletingLastPathComponent()
            .appending(path: "\(DraftTemplate.slug(fromTitle: newTitle)).md")
        storedDocuments = storedDocuments.map { document in
            guard document.url == url else { return document }
            return VaultDocument(url: destination, title: newTitle, modifiedAt: document.modifiedAt)
        }
        return destination
    }

    func setArrangement(_ arrangement: CanvasArrangement) {
        self.arrangement = arrangement
    }

    func setContents(_ contents: String, at url: URL) {
        storedContents[url] = contents
    }

    func setLocation(_ location: URL?) { self.location = location }

    func currentStreakGoal() -> StreakGoal { streakGoal }

    func recordWords(_ words: Int) {
        recordedWords += words
    }

    func setStreakGoal(_ goal: StreakGoal) {
        streakGoal = goal
    }

    func stats() -> VaultStats {
        VaultStats(dotCount: storedDots.count, draftCount: storedDocuments.count)
    }

    func updateDot(_ dot: Dot) {
        storedDots = storedDots.map { $0.id == dot.id ? dot : $0 }
    }
}
