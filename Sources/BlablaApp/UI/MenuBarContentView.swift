import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Blabla", systemImage: controller.menuBarSymbolName)
                    .font(.headline)
                Spacer()
                Text(controller.settings.selectedLanguage.code.uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(controller.widgetMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button(primaryActionTitle) {
                Task {
                    if controller.workflowState == .recording {
                        await controller.stopRecording()
                    } else if controller.canStartRecording {
                        await controller.startRecording()
                    }
                }
            }
            .disabled(controller.workflowState == .transcribing)

            Menu("Language: \(controller.settings.selectedLanguage.name)") {
                ForEach(AppSettings.languages) { language in
                    Button(language.menuLabel) {
                        controller.settings.languageCode = language.code
                    }
                }
            }

            Toggle(
                "Auto-insert",
                isOn: Binding(
                    get: { controller.settings.autoInsert },
                    set: { controller.settings.autoInsert = $0 }
                )
            )

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Provider: \(controller.settings.provider.displayName)")
                Text("Model: \((controller.lastResultModel ?? controller.settings.selectedModel).displayName)")
                Text("Microphone: \(controller.selectedMicrophoneName)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            SettingsLink {
                Text("Settings…")
            }

            Button("Quit") {
                controller.quit()
            }
        }
        .padding(14)
        .frame(width: 320)
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
}
