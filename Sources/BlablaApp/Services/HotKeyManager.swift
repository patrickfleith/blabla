import Carbon
import Foundation

enum HotKeyManagerError: LocalizedError {
    case failedToInstallHandler(OSStatus)
    case failedToRegisterHotKey(OSStatus)

    var errorDescription: String? {
        switch self {
        case .failedToInstallHandler(let status):
            return "Unable to install the global hotkey handler (\(status))."
        case .failedToRegisterHotKey(let status):
            return "Unable to register a global hotkey (\(status))."
        }
    }
}

private let hotKeySignature: OSType = 0x424C424C

private func hotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData,
          let event else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else {
        return status
    }

    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handlePressedHotKey(hotKeyID.id)
    return noErr
}

final class HotKeyManager {
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?

    private var eventHandlerRef: EventHandlerRef?
    private var startHotKeyRef: EventHotKeyRef?
    private var stopHotKeyRef: EventHotKeyRef?

    init() {
        try? installHandler()
    }

    deinit {
        unregisterAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func register(start: KeyboardShortcut, stop: KeyboardShortcut) throws {
        try installHandler()
        unregisterAll()

        var startRef: EventHotKeyRef?
        var startID = EventHotKeyID()
        startID.signature = hotKeySignature
        startID.id = 1
        let startStatus = RegisterEventHotKey(
            start.keyCode,
            start.carbonModifiers,
            startID,
            GetApplicationEventTarget(),
            0,
            &startRef
        )
        guard startStatus == noErr else {
            throw HotKeyManagerError.failedToRegisterHotKey(startStatus)
        }

        var stopRef: EventHotKeyRef?
        var stopID = EventHotKeyID()
        stopID.signature = hotKeySignature
        stopID.id = 2
        let stopStatus = RegisterEventHotKey(
            stop.keyCode,
            stop.carbonModifiers,
            stopID,
            GetApplicationEventTarget(),
            0,
            &stopRef
        )
        guard stopStatus == noErr else {
            if let startRef {
                UnregisterEventHotKey(startRef)
            }
            throw HotKeyManagerError.failedToRegisterHotKey(stopStatus)
        }

        startHotKeyRef = startRef
        stopHotKeyRef = stopRef
    }

    func unregisterAll() {
        if let startHotKeyRef {
            UnregisterEventHotKey(startHotKeyRef)
        }
        if let stopHotKeyRef {
            UnregisterEventHotKey(stopHotKeyRef)
        }
        startHotKeyRef = nil
        stopHotKeyRef = nil
    }

    fileprivate func handlePressedHotKey(_ id: UInt32) {
        switch id {
        case 1:
            onStart?()
        case 2:
            onStop?()
        default:
            break
        }
    }

    private func installHandler() throws {
        guard eventHandlerRef == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard status == noErr else {
            throw HotKeyManagerError.failedToInstallHandler(status)
        }
    }
}
