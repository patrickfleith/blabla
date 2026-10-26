import AppKit
import Combine
import Foundation

@MainActor
final class AppController: NSObject, ObservableObject {
    static let shared = AppController()

    @Published private(set) var workflowState: RecordingWorkflowState = .idle
    @Published private(set) var widgetMessage = "Ready to transcribe."
    @Published private(set) var meterLevel = 0.0
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var availableMicrophones: [MicrophoneDevice] = []
    @Published private(set) var lastTranscriptPreview = ""
    @Published private(set) var lastResultModel: TranscriptionModel?
    @Published private(set) var lastInsertOutcome: InsertOutcome?

    let settings = AppSettings.shared

    private let keychain = KeychainService()
    private lazy var transcriptionService = TranscriptionService(keychain: keychain)
    private let hotKeyManager = HotKeyManager()
    private let audioCaptureService = AudioCaptureService()
    private let pasteboardInsertService = PasteboardInsertService()
    private let soundFeedbackService = SoundFeedbackService(volume: AppSettings.shared.beepVolume)
    private let floatingWidgetController = FloatingWidgetController()

    private var subscriptions = Set<AnyCancellable>()
    private var isBootstrapped = false
    private var isStoppingRecording = false
    private var autoHideTask: Task<Void, Never>?
    private var autoInsertTargetContext: AutoInsertTargetContext?
    private var shortcutPressedAt: Date?

    var menuBarSymbolName: String {
        switch workflowState {
        case .idle:
            return "mic.circle"
        case .recording:
            return "waveform.circle.fill"
        case .transcribing:
            return "hourglass.circle"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var providerModels: [TranscriptionModel] {
        TranscriptionModel.models(for: settings.provider)
    }

    var selectedMicrophoneName: String {
        if let microphoneID = settings.microphoneID,
           let match = availableMicrophones.first(where: { $0.id == microphoneID }) {
            return match.name
        }

        if let defaultDevice = availableMicrophones.first(where: \.isDefault) {
            return "Default (\(defaultDevice.name))"
        }

        return "System default"
    }

    var canStartRecording: Bool {
        workflowState != .recording && workflowState != .transcribing
    }

    var canStopRecording: Bool {
        workflowState == .recording && !isStoppingRecording
    }

    func bootstrap() {
        guard !isBootstrapped else {
            return
        }
        isBootstrapped = true

        audioCaptureService.onMeterLevelChanged = { [weak self] level in
            Task { @MainActor in
                self?.meterLevel = level
            }
        }
        audioCaptureService.onElapsedTimeChanged = { [weak self] elapsed in
            Task { @MainActor in
                guard let self else {
                    return
                }
                self.elapsedTime = elapsed
                if self.workflowState == .recording,
                   elapsed >= Double(AppSettings.maxDurationSeconds),
                   !self.isStoppingRecording {
                    Task {
                        await self.stopRecording()
                    }
                }
            }
        }

        hotKeyManager.onStart = { [weak self] in
            Task { @MainActor in
                self?.shortcutPressedAt = Date()
                await self?.toggleRecording()
            }
        }
        hotKeyManager.onStartReleased = { [weak self] in
            Task { @MainActor in
                await self?.handleStartShortcutReleased()
            }
        }
        hotKeyManager.onStop = { [weak self] in
            Task { @MainActor in
                await self?.stopRecording()
            }
        }
        hotKeyManager.onCancel = { [weak self] in
            Task { @MainActor in
                await self?.cancelRecording()
            }
        }

        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscriptions)

        settings.$startShortcut
            .combineLatest(settings.$stopShortcut)
            .sink { [weak self] startShortcut, stopShortcut in
                self?.registerHotKeys(start: startShortcut, stop: stopShortcut)
            }
            .store(in: &subscriptions)

        settings.$provider
            .sink { [weak self] _ in
                self?.lastResultModel = nil
            }
            .store(in: &subscriptions)

        settings.$beepVolume
            .removeDuplicates()
            .sink { [weak self] volume in
                self?.soundFeedbackService.volume = volume
            }
            .store(in: &subscriptions)

        refreshMicrophones()
        soundFeedbackService.volume = settings.beepVolume
        registerHotKeys(start: settings.startShortcut, stop: settings.stopShortcut)
    }

    func shutdown() {
        autoHideTask?.cancel()
        hotKeyManager.unregisterAll()
        audioCaptureService.shutdown()
        floatingWidgetController.hide()
    }

    func refreshMicrophones() {
        availableMicrophones = audioCaptureService.availableMicrophones()
        if let microphoneID = settings.microphoneID,
           !availableMicrophones.contains(where: { $0.id == microphoneID }) {
            settings.microphoneID = nil
        }
    }

    func toggleRecording() async {
        if workflowState == .recording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    func startRecording() async {
        guard canStartRecording else {
            return
        }

        autoHideTask?.cancel()
        autoInsertTargetContext = settings.autoInsert ? pasteboardInsertService.captureTargetContext() : nil
        lastTranscriptPreview = ""
        widgetMessage = "Checking configuration..."
        refreshMicrophones()

        guard transcriptionService.hasAPIKey(for: settings.provider) else {
            presentError("\(settings.provider.displayName) API key is not configured.")
            return
        }

        let permissionGranted = await audioCaptureService.requestPermission()
        guard permissionGranted else {
            presentError(AudioCaptureServiceError.microphonePermissionDenied.localizedDescription)
            return
        }

        if settings.soundsEnabled {
            soundFeedbackService.play(.start)
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        do {
            try await audioCaptureService.startRecording(
                deviceID: settings.microphoneID,
                maximumDuration: Double(AppSettings.maxDurationSeconds)
            )
            elapsedTime = 0
            meterLevel = 0
            workflowState = .recording
            widgetMessage = "Recording from \(selectedMicrophoneName)."
            try? hotKeyManager.registerCancelEscape()
            syncWidgetVisibility()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func stopRecording() async {
        guard canStopRecording else {
            return
        }

        let targetContext = autoInsertTargetContext
        hotKeyManager.unregisterCancel()
        isStoppingRecording = true
        defer {
            isStoppingRecording = false
            self.autoInsertTargetContext = nil
        }

        do {
            let recordingArtifact = try await audioCaptureService.stopRecording()
            defer {
                try? FileManager.default.removeItem(at: recordingArtifact.fileURL)
            }

            elapsedTime = recordingArtifact.duration
            meterLevel = 0

            if settings.soundsEnabled {
                soundFeedbackService.play(.stop)
            }

            workflowState = .transcribing
            widgetMessage = "Transcribing with \(settings.selectedModel.displayName)..."
            syncWidgetVisibility()

            let result = try await transcriptionService.transcribe(
                audioFileURL: recordingArtifact.fileURL,
                provider: settings.provider,
                selectedModel: settings.selectedModel,
                languageCode: settings.languageCode
            )
            lastResultModel = result.model
            lastTranscriptPreview = transcriptPreview(for: result.text)

            let insertOutcome = await pasteboardInsertService.copyAndMaybeInsert(
                result.text,
                autoInsert: settings.autoInsert,
                targetContext: targetContext
            )
            lastInsertOutcome = insertOutcome
            widgetMessage = [insertOutcome.title, insertOutcome.detail].compactMap { $0 }.joined(separator: ". ")

            workflowState = .success
            if settings.soundsEnabled {
                soundFeedbackService.play(.success)
            }
            syncWidgetVisibility()
            if case .inserted = insertOutcome {
                scheduleAutoHide(after: 2.4)
            } else {
                scheduleAutoHide(after: 5)
            }
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func cancelRecording() async {
        guard canStopRecording else {
            return
        }

        autoHideTask?.cancel()
        hotKeyManager.unregisterCancel()
        isStoppingRecording = true
        defer {
            isStoppingRecording = false
            autoInsertTargetContext = nil
        }

        await audioCaptureService.cancelRecording()
        workflowState = .idle
        widgetMessage = "Ready to transcribe."
        lastTranscriptPreview = ""
        meterLevel = 0
        elapsedTime = 0
        syncWidgetVisibility()
    }

    func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func saveAPIKey(_ key: String, for provider: TranscriptionProviderKind) -> String? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Please enter a non-empty API key."
        }

        do {
            try keychain.save(trimmed, account: provider.keychainAccount)
            objectWillChange.send()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func clearAPIKey(for provider: TranscriptionProviderKind) -> String? {
        do {
            try keychain.delete(account: provider.keychainAccount)
            objectWillChange.send()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func isAPIKeyStored(for provider: TranscriptionProviderKind) -> Bool {
        keychain.hasValue(account: provider.keychainAccount)
    }

    func promptForAccessibilityPermission() {
        _ = pasteboardInsertService.requestAccessibilityTrust(prompt: true)
    }

    func playFeedbackPreview() {
        soundFeedbackService.play(.success)
    }

    // In hold-to-talk mode, releasing after a real hold finishes the dictation; a quick tap keeps toggling.
    private func handleStartShortcutReleased() async {
        guard let pressedAt = shortcutPressedAt else {
            return
        }

        shortcutPressedAt = nil
        if settings.holdToTalk, Date().timeIntervalSince(pressedAt) >= 0.5 {
            await stopRecording()
        }
    }

    private func registerHotKeys(start: KeyboardShortcut, stop: KeyboardShortcut) {
        guard start != stop else {
            widgetMessage = "Start and stop shortcuts must be different."
            workflowState = .error
            syncWidgetVisibility()
            scheduleAutoHide(after: 3.5)
            return
        }

        do {
            try hotKeyManager.register(start: start, stop: stop)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func presentError(_ message: String) {
        hotKeyManager.unregisterCancel()
        autoInsertTargetContext = nil
        workflowState = .error
        widgetMessage = message
        syncWidgetVisibility()
        scheduleAutoHide(after: 7)
    }

    private func transcriptPreview(for text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let previewLimit = 220
        guard normalized.count > previewLimit else {
            return normalized
        }

        let endIndex = normalized.index(normalized.startIndex, offsetBy: previewLimit)
        return String(normalized[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private func syncWidgetVisibility() {
        switch workflowState {
        case .idle:
            floatingWidgetController.hide()
        case .recording, .transcribing, .success, .error:
            floatingWidgetController.show(controller: self)
        }
    }

    private func scheduleAutoHide(after seconds: TimeInterval) {
        autoHideTask?.cancel()
        autoHideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await MainActor.run {
                guard let self else {
                    return
                }
                self.workflowState = .idle
                self.widgetMessage = "Ready to transcribe."
                self.syncWidgetVisibility()
            }
        }
    }
}
