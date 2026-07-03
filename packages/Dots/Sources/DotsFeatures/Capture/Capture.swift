public import ComposableArchitecture2
public import DotsDomain
public import Foundation
import Dependencies
import DotsClients
import DotsEngine

/// The quick-capture panel: one polymorphic field. A thought becomes an
/// Inbox idea; a URL becomes a source (fetched and queued for extraction);
/// the mic speaks either. The bar: faster than opening Apple Notes.
@Feature
public struct Capture {
    public enum Status: Equatable, Sendable {
        case captured(String)
        case failed(String)
        case idle
        case working
    }

    public struct State: Equatable {
        public var draft = ""
        public var status: Status = .idle
        public var vault: URL?
        public var voice: VoiceCapture?

        public init() {}
    }

    public enum Action {
        case captured(kind: String)
        case dismissed
        case failed(String)
        case panelOpened
        case reset
        case submitted
        case vaultLoaded(URL?)
        case voiceCaptureEnded
        case voiceCaptureFailed(String)
        case voiceCaptureToggled
        case voiceCleaned(String)
        case voiceSegment(SpeechSegment)
    }

    @StoreTaskID var voiceStream

    @Dependency(\.modelClient) var modelClient
    @Dependency(\.pageClient) var pageClient
    @Dependency(\.speechClient) var speechClient
    @Dependency(\.vaultClient) var vaultClient

    public init() {}

    public var body: some Feature {
        Update { state, action in
            switch action {
            case .captured(let kind):
                state.draft = ""
                state.status = .captured(kind)

            case .dismissed:
                state.status = .idle
                state.voice = nil
                store.addTask {
                    voiceStream.cancel()
                }

            case .failed(let message):
                state.status = .failed(message)

            case .panelOpened:
                state.status = .idle
                store.addTask {
                    let vault = await vaultClient.storedVaultLocation()
                    try store.send(.vaultLoaded(vault))
                }

            case .reset:
                state.status = .idle

            case .submitted:
                submit(store: store, state: &state)

            case .vaultLoaded(let vault):
                state.vault = vault

            case .voiceCaptureEnded:
                finishVoice(store: store, state: &state, cancelStream: false)

            case .voiceCaptureFailed(let message):
                state.status = .failed(message)
                state.voice = nil
                store.addTask {
                    voiceStream.cancel()
                }

            case .voiceCaptureToggled:
                if state.voice != nil {
                    finishVoice(store: store, state: &state, cancelStream: true)
                } else {
                    startVoice(store: store, state: &state)
                }

            case .voiceCleaned(let text):
                state.voice = nil
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { break }
                state.draft = state.draft.isEmpty ? trimmed : state.draft + " " + trimmed

            case .voiceSegment(let segment):
                guard var voice = state.voice, !voice.isCleaning else { break }
                voice.apply(segment)
                state.voice = voice
            }
        }
        .onMount { _ in
            store.addTask {
                let vault = await vaultClient.storedVaultLocation()
                try store.send(.vaultLoaded(vault))
            }
        }
    }
}

// MARK: - Submission & voice

extension Capture {
    fileprivate func submit(store: FeatureStore<State, Action>, state: inout State) {
        guard let vault = state.vault else {
            state.status = .failed("Open Dots and set up a vault first.")
            return
        }
        let trimmed = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.status = .working

        if let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true {
            store.addTask {
                do {
                    let html = try await pageClient.html(url)
                    let extraction = ArticleExtractor.extract(html: html)
                    let seed = SourceSeed(
                        title: extraction.title ?? url.host() ?? "Untitled",
                        content: extraction.text,
                        url: url,
                        author: extraction.author,
                        site: extraction.site ?? url.host()
                    )
                    _ = try await vaultClient.createSource(vault, seed)
                    try store.send(.captured(kind: "Source saved"))
                } catch {
                    try store.send(.failed("Couldn't fetch that page — paste the text instead."))
                }
            }
        } else {
            store.addTask {
                do {
                    _ = try await vaultClient.createDot(vault, DotSeed(content: trimmed))
                    try store.send(.captured(kind: "Idea captured"))
                } catch {
                    try store.send(.failed("Couldn't save — is your vault reachable?"))
                }
            }
        }
    }

    fileprivate func startVoice(store: FeatureStore<State, Action>, state: inout State) {
        state.status = .idle
        state.voice = VoiceCapture()
        store.addTask(id: voiceStream) {
            do {
                for try await segment in speechClient.readySegments() {
                    try store.send(.voiceSegment(segment))
                }
                try store.send(.voiceCaptureEnded)
            } catch is CancellationError {
                // The stop gesture already wound the capture down.
            } catch {
                try store.send(.voiceCaptureFailed(VoiceFlow.describe(error)))
            }
        }
    }

    fileprivate func finishVoice(
        store: FeatureStore<State, Action>,
        state: inout State,
        cancelStream: Bool
    ) {
        guard var voice = state.voice, !voice.isCleaning else { return }
        if cancelStream {
            store.addTask {
                voiceStream.cancel()
            }
        }
        let committed = voice.committed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !committed.isEmpty else {
            state.voice = nil
            return
        }
        voice.isCleaning = true
        voice.volatile = ""
        state.voice = voice
        store.addTask {
            let cleaned = await VoiceFlow.cleaned(committed, modelClient: modelClient)
            try store.send(.voiceCleaned(cleaned))
        }
    }
}
