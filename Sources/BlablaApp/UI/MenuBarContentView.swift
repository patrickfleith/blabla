import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        Button(primaryActionTitle) {
            Task {
                await controller.toggleRecording()
            }
        }
        .disabled(controller.workflowState == .transcribing)

        if controller.canRetry {
            Button("Retry Last Recording") {
                Task {
                    await controller.retryLastRecording()
                }
            }
        }

        Text("Shortcut: \(controller.settings.startShortcut.displayString)")

        Divider()

        Menu("Copy Recent Transcript") {
            ForEach(Array(controller.recentTranscripts.enumerated()), id: \.offset) { _, transcript in
                Button(menuTitle(for: transcript)) {
                    controller.copyToClipboard(transcript)
                }
            }
        }
        .disabled(controller.recentTranscripts.isEmpty)

        Divider()

        Picker(selection: languageBinding) {
            ForEach(AppSettings.languages) { language in
                Text(language.menuLabel).tag(language.code)
            }
        } label: {
            Text("Language: \(controller.settings.selectedLanguage.name)")
        }

        Picker(selection: microphoneBinding) {
            Text("System Default").tag(String?.none)
            ForEach(controller.availableMicrophones) { microphone in
                Text(microphone.name).tag(Optional(microphone.id))
            }
        } label: {
            Text("Microphone: \(microphoneName)")
        }

        Toggle(
            "Auto-insert",
            isOn: Binding(
                get: { controller.settings.autoInsert },
                set: { controller.settings.autoInsert = $0 }
            )
        )

        Divider()

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",")

        Button("Quit Blabla") {
            controller.quit()
        }
        .keyboardShortcut("q")
    }

    private var primaryActionTitle: String {
        switch controller.workflowState {
        case .recording:
            return "Stop Recording"
        case .transcribing:
            return "Transcribing…"
        case .idle, .success, .error:
            return "Start Recording"
        }
    }

    private var microphoneName: String {
        guard let microphoneID = controller.settings.microphoneID,
              let microphone = controller.availableMicrophones.first(where: { $0.id == microphoneID }) else {
            return "System Default"
        }
        return microphone.name
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { controller.settings.languageCode },
            set: { controller.settings.languageCode = $0 }
        )
    }

    private var microphoneBinding: Binding<String?> {
        Binding(
            get: { controller.settings.microphoneID },
            set: { controller.settings.microphoneID = $0 }
        )
    }

    private func menuTitle(for transcript: String) -> String {
        let singleLine = transcript
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return singleLine.count > 60 ? String(singleLine.prefix(60)) + "…" : singleLine
    }
}
