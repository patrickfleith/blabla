import AppKit
@preconcurrency import ApplicationServices
import Carbon
import Foundation

struct AutoInsertTargetContext: Equatable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let applicationName: String

    var displayName: String {
        applicationName
    }
}

enum InsertOutcome: Equatable {
    case inserted(appName: String)
    case copied(reason: String?)

    var title: String {
        switch self {
        case .inserted(let appName):
            return "Inserted into \(appName)"
        case .copied:
            return "Copied — press ⌘V to paste"
        }
    }

    var detail: String? {
        if case .copied(let reason) = self {
            return reason
        }
        return nil
    }
}

@MainActor
final class PasteboardInsertService {
    func captureTargetContext() -> AutoInsertTargetContext? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return nil
        }

        return AutoInsertTargetContext(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            applicationName: app.localizedName ?? app.bundleIdentifier ?? "the current app"
        )
    }

    func copyAndMaybeInsert(
        _ text: String,
        autoInsert: Bool,
        targetContext: AutoInsertTargetContext?
    ) async -> InsertOutcome {
        copyToPasteboard(text)

        guard autoInsert else {
            return .copied(reason: nil)
        }

        guard requestAccessibilityTrust(prompt: true) else {
            return .copied(reason: "Auto-insert needs Accessibility permission.")
        }

        guard let targetContext = targetContext ?? captureTargetContext() else {
            return .copied(reason: "No app to insert into.")
        }

        guard await bringToFront(targetContext) else {
            return .copied(reason: "Couldn't switch back to \(targetContext.displayName).")
        }

        if let focusedElement = focusedElement(for: targetContext.processIdentifier),
           isSecureField(focusedElement) {
            return .copied(reason: "Not inserted into a password field.")
        }

        // Setting kAXSelectedText reports success in Chromium and Electron apps without inserting
        // anything, so a system-level ⌘V is the only path that behaves the same everywhere.
        guard postPasteShortcut() else {
            return .copied(reason: "Couldn't paste into \(targetContext.displayName).")
        }

        return .inserted(appName: targetContext.displayName)
    }

    func requestAccessibilityTrust(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func bringToFront(_ targetContext: AutoInsertTargetContext) async -> Bool {
        guard let application = NSRunningApplication(processIdentifier: targetContext.processIdentifier),
              !application.isTerminated else {
            return false
        }

        if application.isActive {
            return true
        }

        application.activate()
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(25))
            if application.isActive {
                // Give the reactivated window time to restore keyboard focus before pasting.
                try? await Task.sleep(for: .milliseconds(120))
                return true
            }
        }
        return false
    }

    private func focusedElement(for processIdentifier: pid_t) -> AXUIElement? {
        let applicationElement = AXUIElementCreateApplication(processIdentifier)

        if let focusedElement = copyFocusedElement(from: applicationElement) {
            return focusedElement
        }

        let systemElement = AXUIElementCreateSystemWide()
        return copyFocusedElement(from: systemElement)
    }

    private func copyFocusedElement(from element: AXUIElement) -> AXUIElement? {
        var focusedRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )

        guard status == .success,
              let focusedRef else {
            return nil
        }

        return unsafeDowncast(focusedRef, to: AXUIElement.self)
    }

    private func isSecureField(_ element: AXUIElement) -> Bool {
        let role = stringAttributeValue(named: kAXRoleAttribute as String, from: element)?.lowercased() ?? ""
        let subrole = stringAttributeValue(named: kAXSubroleAttribute as String, from: element)?.lowercased() ?? ""
        return role.contains("secure") || subrole.contains("secure")
    }

    private func stringAttributeValue(named name: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard status == .success else {
            return nil
        }
        return value as? String
    }

    private func postPasteShortcut() -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            return false
        }

        // Explicit flags keep modifiers still held from the stop shortcut out of the paste.
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
        return true
    }
}
