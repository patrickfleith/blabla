import SwiftUI

struct ShortcutRecorderView: View {
    let title: String
    @Binding var shortcut: KeyboardShortcut

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                if isRecording {
                    stopMonitoring()
                } else {
                    startMonitoring()
                }
            } label: {
                Text(isRecording ? "Press shortcut…" : shortcut.displayString)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 170)
            }
            .buttonStyle(.bordered)
        }
        .onDisappear {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopMonitoring()
                return nil
            }

            guard let captured = KeyboardShortcut.capture(from: event) else {
                return nil
            }

            shortcut = captured
            stopMonitoring()
            return nil
        }
    }

    private func stopMonitoring() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
        isRecording = false
    }
}
