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
    case copiedOnly(message: String)
    case inserted
}

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
    ) -> InsertOutcome {
        copyToPasteboard(text)

        guard autoInsert else {
            return .copiedOnly(message: "Copied to clipboard.")
        }

        guard requestAccessibilityTrust(prompt: true) else {
            return .copiedOnly(message: "Copied to clipboard. Accessibility permission is required for auto-insert.")
        }

        guard let targetContext = targetContext ?? captureTargetContext() else {
            return .copiedOnly(message: "Copied to clipboard. Blabla could not recover the original app for auto-insert.")
        }

        guard reactivateApplication(for: targetContext) else {
            return .copiedOnly(message: "Copied to clipboard. \(targetContext.displayName) was no longer available for auto-insert.")
        }

        let focusedElement = focusedElement(for: targetContext.processIdentifier)

        if let focusedElement, isSecureField(focusedElement) {
            return .copiedOnly(message: "Copied to clipboard. Auto-insert was blocked in a secure field.")
        }

        if let focusedElement, insertTextDirectly(text, into: focusedElement) {
            return .inserted
        }

        if simulatePasteShortcut(targetPID: targetContext.processIdentifier) {
            return .inserted
        }

        if simulatePasteShortcut(targetPID: nil) {
            return .inserted
        }

        return .copiedOnly(message: "Copied to clipboard. Auto-insert failed in \(targetContext.displayName).")
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

    private func reactivateApplication(for targetContext: AutoInsertTargetContext) -> Bool {
        guard let application = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == targetContext.processIdentifier
        }) else {
            return false
        }

        let activated = application.activate(options: [.activateAllWindows])
        usleep(140_000)
        return activated || NSWorkspace.shared.frontmostApplication?.processIdentifier == targetContext.processIdentifier
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

    private func insertTextDirectly(_ text: String, into element: AXUIElement) -> Bool {
        guard isAttributeSettable(named: kAXSelectedTextAttribute as String, on: element) else {
            return false
        }

        let status = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )
        return status == .success
    }

    private func isAttributeSettable(named name: String, on element: AXUIElement) -> Bool {
        var isSettable: DarwinBoolean = false
        let status = AXUIElementIsAttributeSettable(element, name as CFString, &isSettable)
        return status == .success && isSettable.boolValue
    }

    private func stringAttributeValue(named name: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard status == .success else {
            return nil
        }
        return value as? String
    }

    private func simulatePasteShortcut(targetPID: pid_t?) -> Bool {
        usleep(70_000)

        guard let source = CGEventSource(stateID: .hidSystemState),
              let commandDown = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: CGKeyCode(kVK_Command),
                  keyDown: true
              ),
              let vDown = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: CGKeyCode(kVK_ANSI_V),
                  keyDown: true
              ),
              let vUp = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: CGKeyCode(kVK_ANSI_V),
                  keyDown: false
              ),
              let commandUp = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: CGKeyCode(kVK_Command),
                  keyDown: false
              ) else {
            return false
        }

        vDown.flags = .maskCommand
        vUp.flags = .maskCommand

        post(commandDown, targetPID: targetPID)
        post(vDown, targetPID: targetPID)
        post(vUp, targetPID: targetPID)
        post(commandUp, targetPID: targetPID)
        return true
    }

    private func post(_ event: CGEvent, targetPID: pid_t?) {
        if let targetPID {
            event.postToPid(targetPID)
        } else {
            event.post(tap: .cghidEventTap)
        }
    }
}
