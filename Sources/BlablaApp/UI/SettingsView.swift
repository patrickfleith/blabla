import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var controller: AppController

    @State private var openAIKeyDraft = ""
    @State private var mistralKeyDraft = ""
    @State private var feedbackMessage: String?

    var body: some View {
        Form {
            generalSection
            transcriptionSection
            shortcutsSection
            apiKeySection
            installSection
        }
        .formStyle(.grouped)
        .padding()
    }

    private var generalSection: some View {
        Section("General") {
            Picker("Microphone", selection: microphoneBinding) {
                Text("System default").tag(Optional<String>.none)
                ForEach(controller.availableMicrophones) { microphone in
                    Text(microphone.isDefault ? "\(microphone.name) (default)" : microphone.name)
                        .tag(Optional(microphone.id))
                }
            }

            Toggle("Auto-insert after transcription", isOn: autoInsertBinding)
            Toggle("Play feedback sounds", isOn: soundsEnabledBinding)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Beep volume")
                    Spacer()
                    Text("\(Int((controller.settings.beepVolume * 100).rounded()))%")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Slider(value: beepVolumeBinding, in: 0...1)
                    Button("Preview") {
                        controller.playFeedbackPreview()
                    }
                    .disabled(!controller.settings.soundsEnabled)
                }
                .disabled(!controller.settings.soundsEnabled)

                Text("Applies to the start, stop, and success tones.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Accessibility")
                Spacer()
                Button("Request Permission") {
                    controller.promptForAccessibilityPermission()
                }
            }

            HStack {
                Text("Maximum recording length")
                Spacer()
                Text("15 minutes")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var transcriptionSection: some View {
        Section("Transcription") {
            Picker("Provider", selection: providerBinding) {
                ForEach(TranscriptionProviderKind.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }

            Picker("Model", selection: modelBinding) {
                ForEach(controller.providerModels) { model in
                    Text(model.displayName).tag(model)
                }
            }

            Picker("Language", selection: languageBinding) {
                ForEach(AppSettings.languages) { language in
                    Text(language.menuLabel).tag(language.code)
                }
            }

            Text(controller.settings.selectedModel.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var shortcutsSection: some View {
        Section("Global Shortcuts") {
            ShortcutRecorderView(title: "Start recording", shortcut: startShortcutBinding)
            ShortcutRecorderView(title: "Stop recording", shortcut: stopShortcutBinding)

            Text("Press Escape while recording a shortcut to cancel.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var apiKeySection: some View {
        Section("API Keys") {
            APIKeyRow(
                title: "OpenAI",
                isStored: controller.isAPIKeyStored(for: .openAI),
                keyDraft: $openAIKeyDraft,
                onSave: {
                    feedbackMessage = controller.saveAPIKey(openAIKeyDraft, for: .openAI)
                    if feedbackMessage == nil {
                        openAIKeyDraft = ""
                        feedbackMessage = "OpenAI API key saved."
                    }
                },
                onClear: {
                    feedbackMessage = controller.clearAPIKey(for: .openAI)
                    if feedbackMessage == nil {
                        openAIKeyDraft = ""
                        feedbackMessage = "OpenAI API key removed."
                    }
                }
            )

            APIKeyRow(
                title: "Mistral AI",
                isStored: controller.isAPIKeyStored(for: .mistral),
                keyDraft: $mistralKeyDraft,
                onSave: {
                    feedbackMessage = controller.saveAPIKey(mistralKeyDraft, for: .mistral)
                    if feedbackMessage == nil {
                        mistralKeyDraft = ""
                        feedbackMessage = "Mistral API key saved."
                    }
                },
                onClear: {
                    feedbackMessage = controller.clearAPIKey(for: .mistral)
                    if feedbackMessage == nil {
                        mistralKeyDraft = ""
                        feedbackMessage = "Mistral API key removed."
                    }
                }
            )

            if let feedbackMessage {
                Text(feedbackMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var installSection: some View {
        Section("Build & Install") {
            Text("Build the app bundle from the cloned repository with `./scripts/build_app.sh`, then launch `dist/Blabla.app`.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var providerBinding: Binding<TranscriptionProviderKind> {
        Binding(
            get: { controller.settings.provider },
            set: { controller.settings.setProvider($0) }
        )
    }

    private var modelBinding: Binding<TranscriptionModel> {
        Binding(
            get: { controller.settings.selectedModel },
            set: { controller.settings.setSelectedModel($0) }
        )
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

    private var autoInsertBinding: Binding<Bool> {
        Binding(
            get: { controller.settings.autoInsert },
            set: { controller.settings.autoInsert = $0 }
        )
    }

    private var soundsEnabledBinding: Binding<Bool> {
        Binding(
            get: { controller.settings.soundsEnabled },
            set: { controller.settings.soundsEnabled = $0 }
        )
    }

    private var beepVolumeBinding: Binding<Double> {
        Binding(
            get: { controller.settings.beepVolume },
            set: { controller.settings.beepVolume = $0 }
        )
    }

    private var startShortcutBinding: Binding<KeyboardShortcut> {
        Binding(
            get: { controller.settings.startShortcut },
            set: { controller.settings.startShortcut = $0 }
        )
    }

    private var stopShortcutBinding: Binding<KeyboardShortcut> {
        Binding(
            get: { controller.settings.stopShortcut },
            set: { controller.settings.stopShortcut = $0 }
        )
    }
}

private struct APIKeyRow: View {
    let title: String
    let isStored: Bool
    @Binding var keyDraft: String
    let onSave: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(isStored ? "Stored in Keychain" : "Not configured")
                    .font(.caption)
                    .foregroundStyle(isStored ? Color.secondary : Color.orange)
            }

            SecureField("Paste \(title) API key", text: $keyDraft)

            HStack {
                Button("Save") {
                    onSave()
                }
                Button("Clear") {
                    onClear()
                }
                .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
