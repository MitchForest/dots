import DotsClients
import DotsDomain
import DotsEngine
import Foundation
import Testing

@Suite("VaultClient")
struct VaultClientTests {
    @Test("Opening a vault rewrites legacy idea files; v2 files keep their exact bytes")
    func openVaultNormalizesLegacyIdeaFiles() async throws {
        let vault = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: vault) }
        let ideas = vault.appending(path: VaultLayout.ideasDirectory)
        try FileManager.default.createDirectory(at: ideas, withIntermediateDirectories: true)

        let legacyURL = ideas.appending(path: "01J0LEGACY.md")
        let legacyContents = """
        ---
        id: 01J0LEGACY
        captured_at: 2026-07-01T09:30:00Z
        origin: distilled
        source:
          kind: text
          ref: 01J1SRC
        parents: [01J0PARENT]
        links: [01J0LINKED]
        tags: [one]
        ---
        Old idea.
        """
        try legacyContents.write(to: legacyURL, atomically: true, encoding: .utf8)

        let v2URL = ideas.appending(path: "01J0MODERN.md")
        let v2Dot = Dot(
            id: Dot.ID("01J0MODERN"),
            content: "Already v2.",
            capturedAt: Date(timeIntervalSince1970: 0),
            references: [Reference("01J0LEGACY")],
            tags: ["two"]
        )
        try DotFile.render(v2Dot).write(to: v2URL, atomically: true, encoding: .utf8)
        let v2Bytes = try Data(contentsOf: v2URL)

        let client = VaultClient.live()
        try await client.openVault(vault)
        await client.forgetVault()

        let normalized = try String(contentsOf: legacyURL, encoding: .utf8)
        #expect(normalized.contains("references: [01J0PARENT, 01J0LINKED, 01J1SRC]"))
        #expect(!normalized.contains("origin:"))
        #expect(!normalized.contains("links:"))
        #expect(!normalized.contains("parents:"))
        #expect(DotFile.parse(normalized) == DotFile.parse(legacyContents))
        #expect(try Data(contentsOf: v2URL) == v2Bytes)
    }

    @Test("documentChanges yields after an atomic replace (rename-swap save)")
    func documentChangesSurvivesAtomicReplace() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "draft.md")
        try "first".write(to: file, atomically: true, encoding: .utf8)

        let changes = VaultClient.live().documentChanges(file)
        try "second".write(to: file, atomically: true, encoding: .utf8)

        #expect(await Self.yieldsWithinTimeout(changes))
    }

    @Test("documentChanges yields after an in-place write")
    func documentChangesYieldsOnInPlaceWrite() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "draft.md")
        try "first".write(to: file, atomically: true, encoding: .utf8)

        let changes = VaultClient.live().documentChanges(file)
        try "first, then more".write(to: file, atomically: false, encoding: .utf8)

        #expect(await Self.yieldsWithinTimeout(changes))
    }

    @Test("documentChanges finishes immediately when the file cannot be opened")
    func documentChangesFinishesForMissingFile() async {
        let missing = FileManager.default.temporaryDirectory
            .appending(path: "does-not-exist-\(UUID().uuidString)")
            .appending(path: "draft.md")

        let changes = VaultClient.live().documentChanges(missing)
        var iterator = changes.makeAsyncIterator()
        #expect(await iterator.next() == nil)
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "dots-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// True when the stream yields before the timeout; generous because the
    /// watcher debounces (~200ms) and CI machines stall.
    private static func yieldsWithinTimeout(
        _ stream: AsyncStream<Void>,
        timeout: Duration = .seconds(10)
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next() != nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }
}
