public import Dependencies
public import DotsDomain
public import DotsEngine
public import Foundation

#if canImport(AppKit)
import AppKit
#endif

/// Boundary to the user's vault — the local clone of their corpus repo.
/// Layout and invariants live in .docs/target.md; files are the truth.
///
/// Every endpoint defaults to the loud `unavailable` behavior; `live()` and
/// `inMemory()` override what they implement. Tests override single closures.
public struct VaultClient: Sendable {
    /// Fires when something outside this process wrote into the vault (the
    /// browser-capture host posts a distributed notification).
    public var captureEvents: @Sendable () -> AsyncStream<Void> =
        { AsyncStream { $0.finish() } }
    public var createDot: @Sendable (_ vault: URL, _ seed: DotSeed) async throws -> Dot =
        { _, _ in throw VaultClientError.unavailable }
    public var createDraft: @Sendable (_ vault: URL, _ title: String) async throws -> VaultDocument =
        { _, _ in throw VaultClientError.unavailable }
    public var createFolder: @Sendable (_ vault: URL, _ name: String) async throws -> Void =
        { _, _ in throw VaultClientError.unavailable }
    /// Mints an idea proposal (identity + timestamp) for a source from the
    /// drafted idea texts and persists it.
    public var createProposal: @Sendable (_ vault: URL, _ sourceId: Source.ID, _ ideas: [String]) async throws -> IdeaProposal =
        { _, _, _ in throw VaultClientError.unavailable }
    public var createSource: @Sendable (_ vault: URL, _ seed: SourceSeed) async throws -> Source =
        { _, _ in throw VaultClientError.unavailable }
    public var createDraftFromDots: @Sendable (_ vault: URL, _ dots: [Dot]) async throws -> VaultDocument =
        { _, _ in throw VaultClientError.unavailable }
    public var createVault: @Sendable (_ location: URL) async throws -> Void =
        { _ in throw VaultClientError.unavailable }
    public var deleteDocument: @Sendable (_ url: URL) async throws -> Void =
        { _ in throw VaultClientError.unavailable }
    public var deleteDot: @Sendable (_ vault: URL, _ id: Dot.ID) async throws -> Void =
        { _, _ in throw VaultClientError.unavailable }
    public var deleteSource: @Sendable (_ vault: URL, _ id: Source.ID) async throws -> Void =
        { _, _ in throw VaultClientError.unavailable }
    public var documentChanges: @Sendable (_ url: URL) -> AsyncStream<Void> =
        { _ in AsyncStream { $0.finish() } }
    // periphery:ignore - test support; SPM test targets sit outside this scan
    public var forgetVault: @Sendable () async -> Void = {}
    public var listDots: @Sendable (_ vault: URL) async throws -> [Dot] =
        { _ in throw VaultClientError.unavailable }
    public var listFolders: @Sendable (_ vault: URL) async throws -> [String] =
        { _ in throw VaultClientError.unavailable }
    public var listProposals: @Sendable (_ vault: URL) async throws -> [IdeaProposal] =
        { _ in throw VaultClientError.unavailable }
    /// Fires when a proposal was written or updated (extraction finished, a
    /// review verdict landed — possibly in another process).
    public var proposalEvents: @Sendable () -> AsyncStream<Void> =
        { AsyncStream { $0.finish() } }
    public var listSources: @Sendable (_ vault: URL) async throws -> [Source] =
        { _ in throw VaultClientError.unavailable }
    public var moveDot: @Sendable (_ vault: URL, _ id: Dot.ID, _ folder: String?) async throws -> Void =
        { _, _, _ in throw VaultClientError.unavailable }
    public var moveSource: @Sendable (_ vault: URL, _ id: Source.ID, _ folder: String?) async throws -> Void =
        { _, _, _ in throw VaultClientError.unavailable }
    public var openVault: @Sendable (_ location: URL) async throws -> Void =
        { _ in throw VaultClientError.unavailable }
    public var readArrangement: @Sendable (_ vault: URL) async throws -> CanvasArrangement =
        { _ in throw VaultClientError.unavailable }
    public var readDocument: @Sendable (_ url: URL) async throws -> String =
        { _ in throw VaultClientError.unavailable }
    /// Whether captures are distilled into proposed ideas (the intake
    /// pipeline). Vault-scoped: the preference travels with the files.
    public var readIntakeEnabled: @Sendable (_ vault: URL) async -> Bool = { _ in true }
    public var readStreakGoal: @Sendable (_ vault: URL) async throws -> StreakGoal =
        { _ in throw VaultClientError.unavailable }
    public var recordWordsWritten: @Sendable (_ vault: URL, _ words: Int) async throws -> Void =
        { _, _ in throw VaultClientError.unavailable }
    public var recentDocuments: @Sendable (_ vault: URL) async throws -> [VaultDocument] =
        { _ in throw VaultClientError.unavailable }
    public var renameDocument: @Sendable (_ url: URL, _ newTitle: String) async throws -> URL =
        { _, _ in throw VaultClientError.unavailable }
    public var revealDocument: @Sendable (_ url: URL) async -> Void = { _ in }
    /// Fires when vault-scoped settings changed or the vault was switched —
    /// possibly from another window or process.
    public var settingsEvents: @Sendable () -> AsyncStream<Void> =
        { AsyncStream { $0.finish() } }
    /// Full-text ⌘P: a ranked live scan of drafts, ideas, and sources.
    public var searchVault: @Sendable (_ vault: URL, _ query: String) async throws -> [VaultSearchHit] =
        { _, _ in throw VaultClientError.unavailable }
    public var storedVaultLocation: @Sendable () async -> URL? = { nil }
    public var updateDot: @Sendable (_ vault: URL, _ dot: Dot) async throws -> Void =
        { _, _ in throw VaultClientError.unavailable }
    /// Overwrites the stored proposal with the same id (review-state updates).
    public var updateProposal: @Sendable (_ vault: URL, _ proposal: IdeaProposal) async throws -> Void =
        { _, _ in throw VaultClientError.unavailable }
    public var vaultStats: @Sendable (_ vault: URL) async throws -> VaultStats =
        { _ in throw VaultClientError.unavailable }
    public var writeArrangement: @Sendable (_ vault: URL, _ arrangement: CanvasArrangement) async throws -> Void =
        { _, _ in throw VaultClientError.unavailable }
    public var writeDocument: @Sendable (_ url: URL, _ contents: String) async throws -> Void =
        { _, _ in throw VaultClientError.unavailable }
    public var writeIntakeEnabled: @Sendable (_ vault: URL, _ isEnabled: Bool) async throws -> Void =
        { _, _ in throw VaultClientError.unavailable }
    public var writeStreakGoal: @Sendable (_ vault: URL, _ goal: StreakGoal) async throws -> Void =
        { _, _ in throw VaultClientError.unavailable }

    public init() {}
}

enum VaultClientError: Error, Equatable {
    case dotNotFound
    case invalidFolderName
    case locationNotDirectory
    case sourceNotFound
    case unavailable
}

// MARK: - Live

extension VaultClient {
    public static func live() -> Self {
        var client = Self()
        Self.addVaultEndpoints(to: &client)
        Self.addDocumentEndpoints(to: &client)
        Self.addDotEndpoints(to: &client)
        Self.addSourceEndpoints(to: &client)
        Self.addProposalEndpoints(to: &client)
        Self.addSearchEndpoints(to: &client)
        return client
    }

    private static func addDotEndpoints(to client: inout Self) {
        client.createDot = { vault, seed in
            var generator = SystemRandomNumberGenerator()
            let now = Date()
            let id = ULID.generate(timestamp: now, using: &generator)
            let dot = Dot(
                id: Dot.ID(id),
                content: seed.content,
                capturedAt: now,
                source: seed.source,
                references: seed.references,
                tags: seed.tags,
                folder: seed.folder
            )
            let directory = Self.folderDirectory(
                root: vault.appending(path: VaultLayout.ideasDirectory),
                folder: seed.folder
            )
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try DotFile.render(dot).write(
                to: directory.appending(path: "\(id).md"),
                atomically: true,
                encoding: .utf8
            )
            return dot
        }
        client.deleteDot = { vault, id in
            guard let url = Self.dotURL(vault: vault, id: id) else {
                throw VaultClientError.dotNotFound
            }
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
        client.listDots = { vault in
            let root = vault.appending(path: VaultLayout.ideasDirectory)
            return Self.markdownURLs(under: root)
                .compactMap { url -> Dot? in
                    guard let contents = try? String(contentsOf: url, encoding: .utf8),
                          var dot = DotFile.parse(contents)
                    else { return nil }
                    dot.folder = Self.folder(of: url, root: root)
                    return dot
                }
                .sorted { $0.capturedAt > $1.capturedAt }
        }
        client.moveDot = { vault, id, folder in
            guard let url = Self.dotURL(vault: vault, id: id) else {
                throw VaultClientError.dotNotFound
            }
            try Self.move(
                file: url,
                toFolder: folder,
                root: vault.appending(path: VaultLayout.ideasDirectory)
            )
        }
        client.readArrangement = { vault in
            let url = Self.arrangementURL(vault: vault)
            guard let data = try? Data(contentsOf: url) else { return CanvasArrangement() }
            return try CanvasArrangement.decode(from: data)
        }
        client.updateDot = { vault, dot in
            guard let url = Self.dotURL(vault: vault, id: dot.id) else {
                throw VaultClientError.dotNotFound
            }
            try DotFile.render(dot).write(to: url, atomically: true, encoding: .utf8)
        }
        client.vaultStats = { vault in
            let calendar = Calendar.current
            var activity: [Date: Int] = [:]

            let ideasRoot = vault.appending(path: VaultLayout.ideasDirectory)
            let dotDates = Self.markdownURLs(under: ideasRoot).compactMap { url -> Date? in
                guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                return DotFile.parse(contents)?.capturedAt
            }
            for date in dotDates {
                activity[calendar.startOfDay(for: date), default: 0] += 1
            }

            let drafts = vault.appending(path: VaultLayout.draftsDirectory)
            let draftURLs = ((try? FileManager.default.contentsOfDirectory(
                at: drafts,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )) ?? []).filter { $0.pathExtension == "md" }
            for url in draftURLs {
                guard let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate
                else { continue }
                activity[calendar.startOfDay(for: modified), default: 0] += 1
            }

            var wordsByDay: [Date: Int] = [:]
            if let data = try? Data(contentsOf: Self.activityURL(vault: vault)),
               let map = try? JSONDecoder().decode([String: Int].self, from: data) {
                for (key, words) in map {
                    guard let day = Self.day(fromKey: key) else { continue }
                    wordsByDay[day] = words
                }
            }

            return VaultStats(
                activityByDay: activity,
                dotCount: dotDates.count,
                draftCount: draftURLs.count,
                wordsByDay: wordsByDay
            )
        }
        client.writeArrangement = { vault, arrangement in
            let url = Self.arrangementURL(vault: vault)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try arrangement.encoded().write(to: url)
        }
    }

    private static func addSourceEndpoints(to client: inout Self) {
        client.createSource = { vault, seed in
            var generator = SystemRandomNumberGenerator()
            let now = Date()
            let id = ULID.generate(timestamp: now, using: &generator)
            let source = Source(
                id: Source.ID(id),
                title: seed.title,
                content: seed.content,
                capturedAt: now,
                url: seed.url,
                author: seed.author,
                site: seed.site,
                folder: seed.folder
            )
            let directory = Self.folderDirectory(
                root: vault.appending(path: VaultLayout.sourcesDirectory),
                folder: seed.folder
            )
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try SourceFile.render(source).write(
                to: directory.appending(path: "\(id).md"),
                atomically: true,
                encoding: .utf8
            )
            // The same signal the browser host posts: every capture path —
            // extension, menu bar, in-app paste — drives reloads and the
            // extraction scan through one event.
            Self.postCaptured()
            return source
        }
        client.deleteSource = { vault, id in
            guard let url = Self.sourceURL(vault: vault, id: id) else {
                throw VaultClientError.sourceNotFound
            }
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
        client.listSources = { vault in
            let root = vault.appending(path: VaultLayout.sourcesDirectory)
            return Self.markdownURLs(under: root)
                .compactMap { url -> Source? in
                    guard let contents = try? String(contentsOf: url, encoding: .utf8),
                          var source = SourceFile.parse(contents)
                    else { return nil }
                    source.folder = Self.folder(of: url, root: root)
                    return source
                }
                .sorted { $0.capturedAt > $1.capturedAt }
        }
        client.moveSource = { vault, id, folder in
            guard let url = Self.sourceURL(vault: vault, id: id) else {
                throw VaultClientError.sourceNotFound
            }
            try Self.move(
                file: url,
                toFolder: folder,
                root: vault.appending(path: VaultLayout.sourcesDirectory)
            )
        }
    }

    /// Registered last: search composes the other endpoints, so it reads
    /// exactly what the rest of the app reads.
    private static func addSearchEndpoints(to client: inout Self) {
        let listDots = client.listDots
        let listSources = client.listSources
        let readDocument = client.readDocument
        let recentDocuments = client.recentDocuments
        client.searchVault = { vault, query in
            let dots = try await listDots(vault)
            let sources = try await listSources(vault)
            var drafts: [(document: VaultDocument, content: String)] = []
            for document in try await recentDocuments(vault) {
                let content = (try? await readDocument(document.url)) ?? ""
                drafts.append((document, content))
            }
            return VaultSearch.rank(query: query, drafts: drafts, dots: dots, sources: sources)
        }
    }

    private static func postSettingsChanged() {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("blog.dots.settings-changed"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private static func postCaptured() {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("blog.dots.captured"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private static func addVaultEndpoints(to client: inout Self) {
        client.captureEvents = {
            AsyncStream { continuation in
                let task = Task {
                    let notifications = DistributedNotificationCenter.default().notifications(
                        named: Notification.Name("blog.dots.captured")
                    )
                    for await _ in notifications {
                        continuation.yield(())
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        client.settingsEvents = {
            AsyncStream { continuation in
                let task = Task {
                    let notifications = DistributedNotificationCenter.default().notifications(
                        named: Notification.Name("blog.dots.settings-changed")
                    )
                    for await _ in notifications {
                        continuation.yield(())
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        client.proposalEvents = {
            AsyncStream { continuation in
                let task = Task {
                    let notifications = DistributedNotificationCenter.default().notifications(
                        named: Notification.Name("blog.dots.proposals-changed")
                    )
                    for await _ in notifications {
                        continuation.yield(())
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        client.createFolder = { vault, name in
            let cleaned = name.trimmingCharacters(in: .whitespaces)
            guard !cleaned.isEmpty, !cleaned.contains("/") else {
                throw VaultClientError.invalidFolderName
            }
            try FileManager.default.createDirectory(
                at: vault.appending(path: VaultLayout.ideasDirectory).appending(path: cleaned),
                withIntermediateDirectories: true
            )
        }
        client.listFolders = { vault in
            var names = Set<String>()
            for root in [VaultLayout.ideasDirectory, VaultLayout.sourcesDirectory] {
                let entries = (try? FileManager.default.contentsOfDirectory(
                    at: vault.appending(path: root),
                    includingPropertiesForKeys: [.isDirectoryKey]
                )) ?? []
                for entry in entries
                where (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    names.insert(entry.lastPathComponent)
                }
            }
            return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        client.readIntakeEnabled = { vault in
            Self.readSettings(vault: vault).isIntakeEnabled ?? true
        }
        client.readStreakGoal = { vault in
            Self.readSettings(vault: vault).streakGoal ?? StreakGoal()
        }
        client.recordWordsWritten = { vault, words in
            let url = Self.activityURL(vault: vault)
            var map = (try? Data(contentsOf: url)).flatMap {
                try? JSONDecoder().decode([String: Int].self, from: $0)
            } ?? [:]
            map[Self.dayKey(Date()), default: 0] += words
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try (try encoder.encode(map)).write(to: url)
        }
        client.writeIntakeEnabled = { vault, isEnabled in
            var settings = Self.readSettings(vault: vault)
            settings.isIntakeEnabled = isEnabled
            try Self.writeSettings(settings, vault: vault)
            Self.postSettingsChanged()
        }
        client.writeStreakGoal = { vault, goal in
            // Read-modify-write: settings.json carries more than the goal.
            var settings = Self.readSettings(vault: vault)
            settings.streakGoal = goal
            try Self.writeSettings(settings, vault: vault)
            Self.postSettingsChanged()
        }
        client.createVault = { location in
            try Self.scaffold(location)
            Self.gitInit(location)
            Self.remember(location)
        }
        client.forgetVault = {
            UserDefaults.standard.removeObject(forKey: Self.vaultDefaultsKey)
        }
        client.openVault = { location in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: location.path(), isDirectory: &isDirectory),
                  isDirectory.boolValue
            else { throw VaultClientError.locationNotDirectory }
            try Self.scaffold(location)
            Self.remember(location)
            Self.postSettingsChanged()
        }
        client.storedVaultLocation = {
            guard let path = UserDefaults.standard.string(forKey: Self.vaultDefaultsKey) else {
                return nil
            }
            let location = URL(filePath: path, directoryHint: .isDirectory)
            // Resuming counts as opening: keep the layout current (this is
            // where the legacy dots/YYYY/MM migration runs on old vaults).
            try? Self.scaffold(location)
            return location
        }
    }

    private static func addDocumentEndpoints(to client: inout Self) {
        client.createDraft = { vault, title in
            try Self.writeDraft(vault: vault, title: title, ideas: [])
        }
        client.createDraftFromDots = { vault, dots in
            // Sent ideas become frontmatter references — never body text.
            // The body starts blank; the raw material sits beside it.
            try Self.writeDraft(
                vault: vault,
                title: "Untitled",
                ideas: dots.map(\.id.rawValue)
            )
        }
        client.deleteDocument = { url in
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
        client.documentChanges = { url in
            // DispatchSource file watching (DocumentWatcher.swift). Survives
            // atomic replaces and editors that rename-swap; bursts debounce
            // to one yield.
            Self.documentChangeStream(url: url)
        }
        client.readDocument = { url in
            try String(contentsOf: url, encoding: .utf8)
        }
        client.recentDocuments = { vault in
            let drafts = vault.appending(path: VaultLayout.draftsDirectory)
            let keys: Set<URLResourceKey> = [.contentModificationDateKey]
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: drafts,
                includingPropertiesForKeys: Array(keys)
            )) ?? []

            let documents = urls
                .filter { $0.pathExtension == "md" }
                .map { url in
                    let modified = (try? url.resourceValues(forKeys: keys))?
                        .contentModificationDate ?? .distantPast
                    let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                    let title = DocumentTitle.parse(contents)
                        ?? url.deletingPathExtension().lastPathComponent
                    return VaultDocument(url: url, title: title, modifiedAt: modified)
                }
                .sorted { $0.modifiedAt > $1.modifiedAt }
            return documents
        }
        client.renameDocument = { url, newTitle in
            if let contents = try? String(contentsOf: url, encoding: .utf8) {
                let retitled = DraftTemplate.replacingTitle(in: contents, with: newTitle)
                try retitled.write(to: url, atomically: true, encoding: .utf8)
            }

            let slug = DraftTemplate.slug(fromTitle: newTitle)
            guard !slug.isEmpty else { return url }
            var destination = url.deletingLastPathComponent().appending(path: "\(slug).md")
            guard destination != url else { return url }
            if FileManager.default.fileExists(atPath: destination.path()) {
                let suffix = String(UInt64(Date().timeIntervalSince1970), radix: 36)
                destination = url.deletingLastPathComponent().appending(path: "\(slug)-\(suffix).md")
            }
            try FileManager.default.moveItem(at: url, to: destination)
            return destination
        }
        client.revealDocument = { url in
            #if canImport(AppKit)
            await MainActor.run {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            #endif
        }
        client.writeDocument = { url, contents in
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static let vaultDefaultsKey = "blog.dots.vault-location"

    private static func arrangementURL(vault: URL) -> URL {
        vault.appending(path: VaultLayout.metadataDirectory).appending(path: "canvas.json")
    }

    private static func activityURL(vault: URL) -> URL {
        vault.appending(path: VaultLayout.metadataDirectory).appending(path: "activity.json")
    }

    private static func settingsURL(vault: URL) -> URL {
        vault.appending(path: VaultLayout.metadataDirectory).appending(path: "settings.json")
    }

    private static func readSettings(vault: URL) -> StoredVaultSettings {
        guard let data = try? Data(contentsOf: Self.settingsURL(vault: vault)),
              let settings = try? JSONDecoder().decode(StoredVaultSettings.self, from: data)
        else { return StoredVaultSettings() }
        return settings
    }

    private static func writeSettings(_ settings: StoredVaultSettings, vault: URL) throws {
        let url = Self.settingsURL(vault: vault)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (try encoder.encode(settings)).write(to: url)
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Calendar.current.startOfDay(for: date))
    }

    private static func day(fromKey key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.date(from: key).map { Calendar.current.startOfDay(for: $0) }
    }

    private static func markdownURLs(under root: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        )
        var urls: [URL] = []
        while let entry = enumerator?.nextObject() as? URL {
            if entry.pathExtension == "md" {
                urls.append(entry)
            }
        }
        return urls
    }

    private static func dotURL(vault: URL, id: Dot.ID) -> URL? {
        markdownURLs(under: vault.appending(path: VaultLayout.ideasDirectory))
            .first { $0.lastPathComponent == "\(id.rawValue).md" }
    }

    /// The directory for a folder under a root — the root itself when
    /// unfiled (folders are one level deep by design).
    private static func folderDirectory(root: URL, folder: String?) -> URL {
        guard let folder, !folder.isEmpty else { return root }
        return root.appending(path: folder)
    }

    /// The folder a file lives in: its parent directory's name, nil when the
    /// parent is the root itself.
    private static func folder(of file: URL, root: URL) -> String? {
        let parent = file.deletingLastPathComponent().standardizedFileURL
        guard parent != root.standardizedFileURL else { return nil }
        return parent.lastPathComponent
    }

    private static func move(file: URL, toFolder folder: String?, root: URL) throws {
        let directory = Self.folderDirectory(root: root, folder: folder)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appending(path: file.lastPathComponent)
        guard destination.standardizedFileURL != file.standardizedFileURL else { return }
        try FileManager.default.moveItem(at: file, to: destination)
    }

    private static func sourceURL(vault: URL, id: Source.ID) -> URL? {
        markdownURLs(under: vault.appending(path: VaultLayout.sourcesDirectory))
            .first { $0.lastPathComponent == "\(id.rawValue).md" }
    }

    private static func writeDraft(
        vault: URL,
        title: String,
        ideas: [String]
    ) throws -> VaultDocument {
        var generator = SystemRandomNumberGenerator()
        let now = Date()
        let id = ULID.generate(timestamp: now, using: &generator)
        let slug = DraftTemplate.slug(fromTitle: title)
        let name = slug.isEmpty ? id.lowercased() : slug
        let drafts = vault.appending(path: VaultLayout.draftsDirectory)

        var url = drafts.appending(path: "\(name).md")
        if FileManager.default.fileExists(atPath: url.path()) {
            url = drafts.appending(path: "\(name)-\(id.lowercased().suffix(6)).md")
        }
        let contents = DraftTemplate.render(id: id, title: title, createdAt: now, ideas: ideas)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return VaultDocument(url: url, title: title, modifiedAt: now)
    }

    private static func scaffold(_ location: URL) throws {
        try Self.migrateLegacyLayout(location)
        for directory in VaultLayout.directories {
            try FileManager.default.createDirectory(
                at: location.appending(path: directory),
                withIntermediateDirectories: true
            )
        }
        let gitignore = location.appending(path: ".gitignore")
        if !FileManager.default.fileExists(atPath: gitignore.path()) {
            try "\(VaultLayout.metadataDirectory)/index.sqlite\n.DS_Store\n"
                .write(to: gitignore, atomically: true, encoding: .utf8)
        }
        try Self.normalizeLegacyIdeaFiles(location)
    }

    /// Pre-v2 idea files carry `origin:`/`links:`/`parents:` frontmatter.
    /// Re-render those through the DotFile codec so the on-disk schema is v2;
    /// files without legacy keys are never rewritten (their bytes — and git
    /// diffs — stay untouched).
    private static func normalizeLegacyIdeaFiles(_ location: URL) throws {
        let root = location.appending(path: VaultLayout.ideasDirectory)
        for url in Self.markdownURLs(under: root) {
            guard let contents = try? String(contentsOf: url, encoding: .utf8),
                  Self.hasLegacyFrontmatterKeys(contents),
                  let dot = DotFile.parse(contents)
            else { continue }
            try DotFile.render(dot).write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// True when a legacy top-level key sits inside the frontmatter fence.
    private static func hasLegacyFrontmatterKeys(_ contents: String) -> Bool {
        let lines = contents.components(separatedBy: "\n")
        guard lines.first == "---",
              let closing = lines.dropFirst().firstIndex(of: "---")
        else { return false }
        return lines[1..<closing].contains { line in
            line.hasPrefix("origin:") || line.hasPrefix("links:") || line.hasPrefix("parents:")
        }
    }

    /// Pre-v2 vaults stored files under `dots/YYYY/MM` and `sources/YYYY/MM`.
    /// Flatten both into the v2 roots (folders are meaningful directories
    /// now) and retire `dots/`. Triggered by the legacy `dots/` dir existing.
    private static func migrateLegacyLayout(_ location: URL) throws {
        let legacyDots = location.appending(path: VaultLayout.legacyDotsDirectory)
        guard FileManager.default.fileExists(atPath: legacyDots.path()) else { return }

        let ideas = location.appending(path: VaultLayout.ideasDirectory)
        try FileManager.default.createDirectory(at: ideas, withIntermediateDirectories: true)
        for file in Self.markdownURLs(under: legacyDots) {
            let destination = ideas.appending(path: file.lastPathComponent)
            if !FileManager.default.fileExists(atPath: destination.path()) {
                try FileManager.default.moveItem(at: file, to: destination)
            }
        }
        try? FileManager.default.removeItem(at: legacyDots)

        // Sources: flatten YYYY/MM date directories into the root; leave any
        // non-date directory alone (it's already a folder).
        let sources = location.appending(path: VaultLayout.sourcesDirectory)
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: sources,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        for entry in entries where entry.lastPathComponent.wholeMatch(of: /\d{4}/) != nil {
            for file in Self.markdownURLs(under: entry) {
                let destination = sources.appending(path: file.lastPathComponent)
                if !FileManager.default.fileExists(atPath: destination.path()) {
                    try FileManager.default.moveItem(at: file, to: destination)
                }
            }
            try? FileManager.default.removeItem(at: entry)
        }
    }

    /// Best-effort `git init` — history from day one, but a missing git
    /// binary must never block vault creation.
    private static func gitInit(_ location: URL) {
        guard !FileManager.default.fileExists(atPath: location.appending(path: ".git").path()) else {
            return
        }
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = ["init", "--quiet", "--initial-branch", "main"]
        process.currentDirectoryURL = location
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private static func remember(_ location: URL) {
        UserDefaults.standard.set(location.path(), forKey: Self.vaultDefaultsKey)
    }
}

/// On-disk shape of `.dots/settings.json`. Every field optional so older
/// vaults decode; writers read-modify-write to preserve fields they don't own.
private struct StoredVaultSettings: Codable {
    var isIntakeEnabled: Bool?
    var streakGoal: StreakGoal?

    init(streakGoal: StreakGoal? = nil, isIntakeEnabled: Bool? = nil) {
        self.isIntakeEnabled = isIntakeEnabled
        self.streakGoal = streakGoal
    }
}

enum VaultClientKey: DependencyKey {
    static var liveValue: VaultClient { .live() }
    static var testValue: VaultClient { .unavailable }
}

extension DependencyValues {
    public var vaultClient: VaultClient {
        get { self[VaultClientKey.self] }
        set { self[VaultClientKey.self] = newValue }
    }
}
