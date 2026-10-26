import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let maxDurationSeconds = 15 * 60

    static let languages: [TranscriptionLanguage] = [
        .init(code: "en", name: "English"),
        .init(code: "fr", name: "French"),
        .init(code: "de", name: "German"),
        .init(code: "es", name: "Spanish"),
        .init(code: "it", name: "Italian"),
        .init(code: "pt", name: "Portuguese"),
        .init(code: "nl", name: "Dutch"),
        .init(code: "sv", name: "Swedish"),
        .init(code: "da", name: "Danish"),
        .init(code: "no", name: "Norwegian"),
        .init(code: "fi", name: "Finnish"),
        .init(code: "pl", name: "Polish"),
        .init(code: "cs", name: "Czech"),
        .init(code: "ro", name: "Romanian"),
        .init(code: "tr", name: "Turkish"),
        .init(code: "ru", name: "Russian"),
        .init(code: "uk", name: "Ukrainian"),
        .init(code: "ar", name: "Arabic"),
        .init(code: "he", name: "Hebrew"),
        .init(code: "hi", name: "Hindi"),
        .init(code: "ja", name: "Japanese"),
        .init(code: "ko", name: "Korean"),
        .init(code: "zh", name: "Chinese"),
        .init(code: "th", name: "Thai"),
        .init(code: "id", name: "Indonesian"),
        .init(code: "vi", name: "Vietnamese"),
    ]

    @Published var provider: TranscriptionProviderKind {
        didSet {
            normalizeModel()
            defaults.set(provider.rawValue, forKey: Keys.provider)
        }
    }

    @Published var selectedModel: TranscriptionModel {
        didSet {
            if selectedModel.provider != provider {
                provider = selectedModel.provider
            }
            defaults.set(selectedModel.rawValue, forKey: Keys.selectedModel)
        }
    }

    @Published var languageCode: String {
        didSet {
            defaults.set(languageCode, forKey: Keys.languageCode)
        }
    }

    @Published var microphoneID: String? {
        didSet {
            defaults.set(microphoneID, forKey: Keys.microphoneID)
        }
    }

    @Published var autoInsert: Bool {
        didSet {
            defaults.set(autoInsert, forKey: Keys.autoInsert)
        }
    }

    @Published var holdToTalk: Bool {
        didSet {
            defaults.set(holdToTalk, forKey: Keys.holdToTalk)
        }
    }

    @Published var soundsEnabled: Bool {
        didSet {
            defaults.set(soundsEnabled, forKey: Keys.soundsEnabled)
        }
    }

    @Published var beepVolume: Double {
        didSet {
            let clamped = Self.clampBeepVolume(beepVolume)
            if clamped != beepVolume {
                beepVolume = clamped
                return
            }
            defaults.set(beepVolume, forKey: Keys.beepVolume)
        }
    }

    @Published var startShortcut: KeyboardShortcut {
        didSet {
            defaults.set(encodeShortcut(startShortcut), forKey: Keys.startShortcut)
        }
    }

    @Published var stopShortcut: KeyboardShortcut {
        didSet {
            defaults.set(encodeShortcut(stopShortcut), forKey: Keys.stopShortcut)
        }
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let providerValue = defaults.string(forKey: Keys.provider)
        let restoredProvider = providerValue.flatMap(TranscriptionProviderKind.init(rawValue:)) ?? .openAI
        provider = restoredProvider

        let modelValue = defaults.string(forKey: Keys.selectedModel)
        let restoredModel = modelValue.flatMap(TranscriptionModel.init(rawValue:)) ?? .gpt4oTranscribe
        selectedModel = restoredModel.provider == restoredProvider ? restoredModel : TranscriptionModel.models(for: restoredProvider).first ?? .gpt4oTranscribe

        let languageValue = defaults.string(forKey: Keys.languageCode)
        languageCode = languageValue ?? Self.defaultLanguageCode()

        microphoneID = defaults.string(forKey: Keys.microphoneID)
        autoInsert = defaults.object(forKey: Keys.autoInsert) as? Bool ?? false
        holdToTalk = defaults.bool(forKey: Keys.holdToTalk)
        soundsEnabled = defaults.object(forKey: Keys.soundsEnabled) as? Bool ?? true
        beepVolume = Self.clampBeepVolume(defaults.object(forKey: Keys.beepVolume) as? Double ?? 0.7)
        startShortcut = Self.decodeShortcut(defaults.data(forKey: Keys.startShortcut)) ?? .defaultStart
        stopShortcut = Self.decodeShortcut(defaults.data(forKey: Keys.stopShortcut)) ?? .defaultStop
    }

    var selectedLanguage: TranscriptionLanguage {
        Self.languages.first(where: { $0.code == languageCode }) ?? TranscriptionLanguage(code: languageCode, name: languageCode.uppercased())
    }

    func setProvider(_ provider: TranscriptionProviderKind) {
        self.provider = provider
        normalizeModel()
    }

    func setSelectedModel(_ model: TranscriptionModel) {
        provider = model.provider
        selectedModel = model
    }

    private func normalizeModel() {
        if selectedModel.provider != provider {
            selectedModel = TranscriptionModel.models(for: provider).first ?? selectedModel
        }
    }

    private func encodeShortcut(_ shortcut: KeyboardShortcut) -> Data? {
        try? JSONEncoder().encode(shortcut)
    }

    private static func decodeShortcut(_ data: Data?) -> KeyboardShortcut? {
        guard let data else {
            return nil
        }
        return try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
    }

    private static func defaultLanguageCode() -> String {
        guard let preferredLanguage = Locale.preferredLanguages.first else {
            return "en"
        }
        let code = preferredLanguage
            .split(separator: "-")
            .first
            .map(String.init) ?? String(preferredLanguage.prefix(2))
        return languages.contains(where: { $0.code == code }) ? code : "en"
    }

    private static func clampBeepVolume(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private enum Keys {
        static let provider = "settings.provider"
        static let selectedModel = "settings.selectedModel"
        static let languageCode = "settings.languageCode"
        static let microphoneID = "settings.microphoneID"
        static let autoInsert = "settings.autoInsert"
        static let holdToTalk = "settings.holdToTalk"
        static let soundsEnabled = "settings.soundsEnabled"
        static let beepVolume = "settings.beepVolume"
        static let startShortcut = "settings.startShortcut"
        static let stopShortcut = "settings.stopShortcut"
    }
}
