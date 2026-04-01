import AppKit
import Carbon

struct KeyboardShortcut: Codable, Equatable, Hashable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let defaultStart = KeyboardShortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey))
    static let defaultStop = KeyboardShortcut(keyCode: UInt32(kVK_Return), modifiers: UInt32(controlKey | optionKey))

    var carbonModifiers: UInt32 {
        modifiers
    }

    var displayString: String {
        let flags = NSEvent.ModifierFlags(carbonModifiers: modifiers)
        let keyName = Self.keyName(for: keyCode)
        let modifierString = [
            flags.contains(.control) ? "⌃" : "",
            flags.contains(.option) ? "⌥" : "",
            flags.contains(.shift) ? "⇧" : "",
            flags.contains(.command) ? "⌘" : "",
        ].joined()
        return modifierString + keyName
    }

    static func capture(from event: NSEvent) -> KeyboardShortcut? {
        let filteredFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let carbonFlags = filteredFlags.carbonHotKeyFlags
        guard carbonFlags != 0 else {
            return nil
        }

        let keyCode = UInt32(event.keyCode)
        if Self.isModifierOnlyKeyCode(keyCode) {
            return nil
        }

        return KeyboardShortcut(keyCode: keyCode, modifiers: carbonFlags)
    }

    static func isModifierOnlyKeyCode(_ keyCode: UInt32) -> Bool {
        switch keyCode {
        case UInt32(kVK_Command), UInt32(kVK_RightCommand),
             UInt32(kVK_Shift), UInt32(kVK_RightShift),
             UInt32(kVK_Option), UInt32(kVK_RightOption),
             UInt32(kVK_Control), UInt32(kVK_RightControl),
             UInt32(kVK_CapsLock), UInt32(kVK_Function):
            return true
        default:
            return false
        }
    }

    private static func keyName(for keyCode: UInt32) -> String {
        let mapping: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A",
            UInt32(kVK_ANSI_B): "B",
            UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D",
            UInt32(kVK_ANSI_E): "E",
            UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G",
            UInt32(kVK_ANSI_H): "H",
            UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J",
            UInt32(kVK_ANSI_K): "K",
            UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M",
            UInt32(kVK_ANSI_N): "N",
            UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P",
            UInt32(kVK_ANSI_Q): "Q",
            UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S",
            UInt32(kVK_ANSI_T): "T",
            UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V",
            UInt32(kVK_ANSI_W): "W",
            UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y",
            UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0",
            UInt32(kVK_ANSI_1): "1",
            UInt32(kVK_ANSI_2): "2",
            UInt32(kVK_ANSI_3): "3",
            UInt32(kVK_ANSI_4): "4",
            UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6",
            UInt32(kVK_ANSI_7): "7",
            UInt32(kVK_ANSI_8): "8",
            UInt32(kVK_ANSI_9): "9",
            UInt32(kVK_Space): "Space",
            UInt32(kVK_Return): "Return",
            UInt32(kVK_Tab): "Tab",
            UInt32(kVK_Escape): "Esc",
            UInt32(kVK_Delete): "Delete",
            UInt32(kVK_ForwardDelete): "Forward Delete",
        ]

        return mapping[keyCode] ?? "Key \(keyCode)"
    }
}

private extension NSEvent.ModifierFlags {
    init(carbonModifiers: UInt32) {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 {
            flags.insert(.command)
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            flags.insert(.option)
        }
        if carbonModifiers & UInt32(controlKey) != 0 {
            flags.insert(.control)
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            flags.insert(.shift)
        }
        self = flags
    }

    var carbonHotKeyFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) {
            flags |= UInt32(cmdKey)
        }
        if contains(.option) {
            flags |= UInt32(optionKey)
        }
        if contains(.control) {
            flags |= UInt32(controlKey)
        }
        if contains(.shift) {
            flags |= UInt32(shiftKey)
        }
        return flags
    }
}
