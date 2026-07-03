import Dispatch
import Foundation
import Synchronization

extension VaultClient {
    /// Bridges a `DocumentWatcher` into the `documentChanges` endpoint:
    /// one stream per call, cleaned up when the consumer stops iterating.
    /// An unopenable file yields nothing and finishes immediately.
    static func documentChangeStream(url: URL) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let watcher = DocumentWatcher(
                path: url.path(percentEncoded: false),
                continuation: continuation
            )
            guard watcher.start() else {
                continuation.finish()
                return
            }
            continuation.onTermination = { _ in watcher.stop() }
        }
    }
}

/// Watches one file for content changes with a kqueue-backed DispatchSource.
/// Atomic replaces (editors rename-swap on save) fire `.delete`/`.rename` on
/// the watched vnode; the watcher re-opens the same path — retrying briefly
/// while the new file lands — so the stream survives them. Event bursts
/// debounce to a single yield.
private final class DocumentWatcher: Sendable {
    private struct State {
        var source: (any DispatchSourceFileSystemObject)?
        var stopped = false
        /// Bumped per event; a scheduled yield only fires when it is still
        /// the latest, which coalesces bursts (DispatchWorkItem cancellation
        /// is off the table — it isn't Sendable).
        var yieldGeneration: UInt64 = 0
    }

    private static let debounce = DispatchTimeInterval.milliseconds(200)
    private static let reattachAttempts = 10
    private static let reattachDelay = DispatchTimeInterval.milliseconds(50)

    private let continuation: AsyncStream<Void>.Continuation
    private let path: String
    private let queue = DispatchQueue(label: "blog.dots.vault.document-watcher")
    private let state = Mutex(State())

    init(path: String, continuation: AsyncStream<Void>.Continuation) {
        self.continuation = continuation
        self.path = path
    }

    /// Starts watching; false when the file can't be opened.
    func start() -> Bool {
        attach()
    }

    func stop() {
        state.withLock { state in
            state.stopped = true
            state.yieldGeneration &+= 1
            state.source?.cancel()
            state.source = nil
        }
    }

    /// Opens the path O_EVTONLY and installs a fresh source. The descriptor
    /// is owned by the source and closed in its cancel handler.
    private func attach() -> Bool {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return false }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.handleEvent()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        let accepted = state.withLock { state -> Bool in
            guard !state.stopped else { return false }
            state.source = source
            return true
        }
        guard accepted else {
            // Raced with stop(): activate after cancel so the cancel handler
            // runs and the descriptor closes.
            source.cancel()
            source.activate()
            return false
        }
        source.activate()
        return true
    }

    private func handleEvent() {
        let raw = state.withLock { $0.source?.data.rawValue }
        guard let raw else { return }
        let events = DispatchSource.FileSystemEvent(rawValue: raw)
        if !events.isDisjoint(with: [.delete, .rename]) {
            detach()
            reattach(attemptsLeft: Self.reattachAttempts)
        }
        scheduleYield()
    }

    private func detach() {
        state.withLock { state in
            state.source?.cancel()
            state.source = nil
        }
    }

    /// Re-opens the path after an atomic replace; the new file may be a
    /// beat behind the rename, so failures retry on a short cadence. When
    /// the file never reappears the stream finishes — it is gone, not changed.
    private func reattach(attemptsLeft: Int) {
        guard state.withLock({ !$0.stopped }) else { return }
        guard !attach() else { return }
        guard attemptsLeft > 1 else {
            continuation.finish()
            return
        }
        queue.asyncAfter(deadline: .now() + Self.reattachDelay) { [weak self] in
            self?.reattach(attemptsLeft: attemptsLeft - 1)
        }
    }

    private func scheduleYield() {
        let generation = state.withLock { state -> UInt64? in
            guard !state.stopped else { return nil }
            state.yieldGeneration &+= 1
            return state.yieldGeneration
        }
        guard let generation else { return }
        queue.asyncAfter(deadline: .now() + Self.debounce) { [weak self] in
            guard let self else { return }
            let isLatest = self.state.withLock { state in
                !state.stopped && state.yieldGeneration == generation
            }
            if isLatest {
                self.continuation.yield(())
            }
        }
    }
}
