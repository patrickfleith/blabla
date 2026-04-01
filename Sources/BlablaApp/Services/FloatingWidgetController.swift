import AppKit
import SwiftUI

@MainActor
final class FloatingWidgetController {
    private var panel: NSPanel?

    func show(controller: AppController) {
        let panelSize = RecordingWidgetView.panelSize(for: controller.workflowState)
        let panel = panel ?? makePanel(controller: controller)
        panel.setContentSize(panelSize)
        panel.contentViewController = NSHostingController(
            rootView: RecordingWidgetView()
                .environmentObject(controller)
        )
        position(panel, panelSize: panelSize)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel(controller: AppController) -> NSPanel {
        let panelSize = RecordingWidgetView.panelSize(for: controller.workflowState)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
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

    private func position(_ panel: NSPanel, panelSize: CGSize) {
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        guard let screen = targetScreen else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let horizontalInset: CGFloat = 24
        let topInset = max(60, panelSize.height * 0.58)
        let unclampedX = visibleFrame.midX - panelSize.width / 2
        let x = min(
            max(unclampedX, visibleFrame.minX + horizontalInset),
            visibleFrame.maxX - panelSize.width - horizontalInset
        )
        let y = visibleFrame.maxY - panelSize.height - topInset
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: panelSize), display: true)
    }
}
