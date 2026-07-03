import AppKit
import Carbon.HIToolbox

/// A Carbon global hotkey — the only sanctioned way to own a system-wide
/// shortcut without the Accessibility permission. Fires while the app runs.
@MainActor
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let handler: () -> Void

    /// Registers immediately; unregisters on deinit.
    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping @MainActor () -> Void) {
        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                // Carbon dispatches on the main thread.
                MainActor.assumeIsolated {
                    hotKey.handler()
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &handlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x444F5453), id: 1) // "DOTS"
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    // No deinit: the hotkey is app-lifetime (the delegate owns it forever),
    // and Carbon unregistration from a nonisolated deinit fights isolation
    // for a cleanup the OS performs at exit anyway.
}
