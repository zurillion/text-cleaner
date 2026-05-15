import AppKit
import Carbon.HIToolbox

/// Registers one or more global hotkeys via Carbon's RegisterEventHotKey
/// and invokes the matching handler on the main queue when each fires.
/// Hotkeys are keyed by a caller-supplied name so they can be re-registered
/// (when the user changes a shortcut in Settings) without affecting other
/// hotkeys owned by the same manager.
final class HotKeyManager {
    private struct Registration {
        let id: UInt32
        let handler: () -> Void
        var hotKeyRef: EventHotKeyRef?
    }

    private var registrations: [String: Registration] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private static let signature: OSType = 0x54584343 // 'TXCC'
    private static var nextID: UInt32 = 1

    init() {
        installEventHandler()
    }

    deinit {
        for reg in registrations.values {
            if let ref = reg.hotKeyRef { UnregisterEventHotKey(ref) }
        }
        if let h = eventHandlerRef { RemoveEventHandler(h) }
    }

    func register(
        name: String,
        shortcut: KeyboardShortcut,
        handler: @escaping () -> Void
    ) {
        unregister(name: name)

        let id = Self.nextID
        Self.nextID &+= 1

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr else {
            NSLog("TextCleaner: RegisterEventHotKey(\(name)) failed with status \(status)")
            return
        }

        registrations[name] = Registration(id: id, handler: handler, hotKeyRef: ref)
    }

    func unregister(name: String) {
        if let reg = registrations[name], let ref = reg.hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        registrations.removeValue(forKey: name)
    }

    fileprivate func dispatch(id: UInt32) {
        guard let reg = registrations.values.first(where: { $0.id == id }) else { return }
        let handler = reg.handler
        DispatchQueue.main.async { handler() }
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData = userData, let event = event else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard err == noErr, hotKeyID.signature == HotKeyManager.signature else {
                    return noErr
                }
                manager.dispatch(id: hotKeyID.id)
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &eventHandlerRef
        )
    }
}
