import AppKit
import SwiftUI

@MainActor
final class FloatingWidgetController {
    private var panel: NSPanel?

    func show(controller: AppController) {
        let panel = panel ?? makePanel(controller: controller)
        guard !panel.isVisible else {
            return
        }

        position(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel(controller: AppController) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: RecordingWidgetView.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = NSHostingController(
            rootView: RecordingWidgetView()
                .environmentObject(controller)
        )

        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        guard let screen = targetScreen else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let size = RecordingWidgetView.panelSize
        let origin = NSPoint(x: visibleFrame.midX - size.width / 2, y: visibleFrame.maxY - size.height - 12)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
