import ComposableArchitecture2
import Dependencies
import DependenciesTestSupport
import DotsClients
import DotsDomain
import DotsFeatures
import Foundation
import Testing

private nonisolated let vaultURL = URL(filePath: "/mock/vault", directoryHint: .isDirectory)

@MainActor
@Suite("Capture")
struct CaptureTests {
    @Test(
        "A typed thought becomes an Inbox idea",
        .dependencies {
            $0.vaultClient = .inMemory(location: vaultURL)
        }
    )
    func thoughtCapture() async {
        let store = TestStore(initialState: Capture.State()) {
            Capture()
        }
        await store.receive(\.vaultLoaded) {
            $0.vault = vaultURL
        }

        await store.modify {
            $0.draft = "An idea worth keeping."
        }
        store.send(.submitted) {
            $0.status = .working
        }
        await store.receive(\.captured) {
            $0.draft = ""
            $0.status = .captured("Idea captured")
        }

        @Dependency(\.vaultClient) var vaultClient
        let dots = try? await vaultClient.listDots(vaultURL)
        #expect(dots?.first?.content == "An idea worth keeping.")
        #expect(dots?.first?.folder == nil)
        await store.dismount()
    }

    @Test(
        "A pasted URL becomes a source",
        .dependencies {
            var page = PageClient()
            page.html = { _ in
                "<html><head><title>An Essay</title></head><body><article><p>Words.</p></article></body></html>"
            }
            $0.pageClient = page
            $0.vaultClient = .inMemory(location: vaultURL)
        }
    )
    func urlCapture() async {
        let store = TestStore(initialState: Capture.State()) {
            Capture()
        }
        await store.receive(\.vaultLoaded) {
            $0.vault = vaultURL
        }

        await store.modify {
            $0.draft = "https://example.com/essay"
        }
        store.send(.submitted) {
            $0.status = .working
        }
        await store.receive(\.captured) {
            $0.draft = ""
            $0.status = .captured("Source saved")
        }

        @Dependency(\.vaultClient) var vaultClient
        let sources = try? await vaultClient.listSources(vaultURL)
        #expect(sources?.first?.title == "An Essay")
        #expect(sources?.first?.content == "Words.")
        await store.dismount()
    }

    @Test(
        "No vault fails loudly instead of silently dropping the thought",
        .dependencies {
            $0.vaultClient = .inMemory(location: nil)
        }
    )
    func missingVault() async {
        let store = TestStore(initialState: Capture.State()) {
            Capture()
        }
        await store.receive(\.vaultLoaded)

        await store.modify {
            $0.draft = "orphan thought"
        }
        store.send(.submitted) {
            $0.status = .failed("Open Dots and set up a vault first.")
        }
        await store.dismount()
    }
}
