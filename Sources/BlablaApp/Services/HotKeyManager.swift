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
    var onCancel: (() -> Void)?

    private var eventHandlerRef: EventHandlerRef?
    private var startHotKeyRef: EventHotKeyRef?
    private var stopHotKeyRef: EventHotKeyRef?
    private var cancelHotKeyRef: EventHotKeyRef?

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
        let shouldRestoreCancel = cancelHotKeyRef != nil
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

        if shouldRestoreCancel {
            try registerCancelEscape()
        }
    }

    func registerCancelEscape() throws {
        try installHandler()
        unregisterCancel()

        var cancelRef: EventHotKeyRef?
        var cancelID = EventHotKeyID()
        cancelID.signature = hotKeySignature
        cancelID.id = 3
        let cancelStatus = RegisterEventHotKey(
            UInt32(kVK_Escape),
            0,
            cancelID,
            GetApplicationEventTarget(),
            0,
            &cancelRef
        )
        guard cancelStatus == noErr else {
            throw HotKeyManagerError.failedToRegisterHotKey(cancelStatus)
        }

        cancelHotKeyRef = cancelRef
    }

    func unregisterCancel() {
        if let cancelHotKeyRef {
            UnregisterEventHotKey(cancelHotKeyRef)
        }
        cancelHotKeyRef = nil
    }

    func unregisterAll() {
        if let startHotKeyRef {
            UnregisterEventHotKey(startHotKeyRef)
        }
        if let stopHotKeyRef {
            UnregisterEventHotKey(stopHotKeyRef)
        }
        if let cancelHotKeyRef {
            UnregisterEventHotKey(cancelHotKeyRef)
        }
        startHotKeyRef = nil
        stopHotKeyRef = nil
        cancelHotKeyRef = nil
    }

    fileprivate func handlePressedHotKey(_ id: UInt32) {
        switch id {
        case 1:
            onStart?()
        case 2:
            onStop?()
        case 3:
            onCancel?()
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
