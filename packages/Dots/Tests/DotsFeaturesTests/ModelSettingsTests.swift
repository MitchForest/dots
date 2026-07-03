import ComposableArchitecture2
import Dependencies
import DependenciesTestSupport
import DotsClients
import DotsDomain
import DotsFeatures
import Testing

@MainActor
@Suite("ModelSettings")
struct ModelSettingsTests {
    @Test(
        "Mount loads the selected provider, key state, and availabilities",
        .dependencies {
            $0.modelClient = .inMemory(selectedProvider: .claude)
        }
    )
    func mountLoads() async {
        let store = TestStore(initialState: ModelSettings.State()) {
            ModelSettings()
        }

        await store.receive(\.providerLoaded) {
            $0.provider = .claude
        }
        await store.receive(\.keyStateLoaded)
        await store.receive(\.availabilityLoaded) {
            $0.availabilityByProvider[.claude] = .available
        }
        await store.receive(\.availabilityLoaded) {
            $0.availabilityByProvider[.onDevice] = .available
        }
        #expect(store.state.selectedAvailability == .available)
        await store.dismount()
    }

    @Test(
        "Selecting a provider persists it",
        .dependencies {
            $0.modelClient = .inMemory()
        }
    )
    func providerSelectionPersists() async {
        let store = TestStore(initialState: ModelSettings.State()) {
            ModelSettings()
        }
        await store.receive(\.providerLoaded)
        await store.receive(\.keyStateLoaded)
        await store.receive(\.availabilityLoaded) {
            $0.availabilityByProvider[.claude] = .available
        }
        await store.receive(\.availabilityLoaded) {
            $0.availabilityByProvider[.onDevice] = .available
        }

        let task = store.send(.providerSelected(.claude)) {
            $0.provider = .claude
        }
        await task?.value

        @Dependency(\.modelClient) var modelClient
        let stored = await modelClient.readSelectedProvider()
        #expect(stored == .claude)
        await store.dismount()
    }

    @Test(
        "Saving a key stores it and refreshes availability; clearing removes it",
        .dependencies {
            $0.modelClient = .inMemory()
        }
    )
    func keyLifecycle() async {
        var state = ModelSettings.State()
        state.keyDraft = "  sk-ant-test  "
        let store = TestStore(initialState: state) {
            ModelSettings()
        }
        await store.receive(\.providerLoaded)
        await store.receive(\.keyStateLoaded)
        await store.receive(\.availabilityLoaded) {
            $0.availabilityByProvider[.claude] = .available
        }
        await store.receive(\.availabilityLoaded) {
            $0.availabilityByProvider[.onDevice] = .available
        }

        store.send(.keySaved) {
            $0.hasStoredKey = true
            $0.keyDraft = ""
        }
        await store.receive(\.availabilityLoaded)

        @Dependency(\.modelClient) var modelClient
        let saved = await modelClient.readAPIKey(.claude)
        #expect(saved == "sk-ant-test")

        store.send(.keyCleared) {
            $0.hasStoredKey = false
        }
        await store.receive(\.availabilityLoaded)
        let cleared = await modelClient.readAPIKey(.claude)
        #expect(cleared == nil)
        await store.dismount()
    }
}
