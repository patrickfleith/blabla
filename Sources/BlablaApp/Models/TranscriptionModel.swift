import Foundation

enum TranscriptionProviderKind: String, CaseIterable, Codable, Identifiable {
    case openAI
    case mistral

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .mistral:
            return "Mistral AI"
        }
    }

    var keychainAccount: String {
        switch self {
        case .openAI:
            return "openai_api_key"
        case .mistral:
            return "mistral_api_key"
        }
    }
}

enum TranscriptionModel: String, CaseIterable, Codable, Identifiable {
    case gpt4oTranscribe = "gpt-4o-transcribe"
    case gpt4oMiniTranscribeSnapshot = "gpt-4o-mini-transcribe-2025-12-15"
    case voxtralMiniTranscribe3 = "voxtral-mini-transcribe-3-0"
    case voxtralSmallTranscribe3 = "voxtral-small-transcribe-3-0"
    case voxtralMiniLatest = "voxtral-mini-latest"

    var id: String {
        rawValue
    }

    var provider: TranscriptionProviderKind {
        switch self {
        case .gpt4oTranscribe, .gpt4oMiniTranscribeSnapshot:
            return .openAI
        case .voxtralMiniTranscribe3, .voxtralSmallTranscribe3, .voxtralMiniLatest:
            return .mistral
        }
    }

    var displayName: String {
        switch self {
        case .gpt4oTranscribe:
            return "gpt-4o-transcribe"
        case .gpt4oMiniTranscribeSnapshot:
            return "gpt-4o-mini-transcribe-2025-12-15"
        case .voxtralMiniTranscribe3:
            return "voxtral-mini-transcribe-3-0"
        case .voxtralSmallTranscribe3:
            return "voxtral-small-transcribe-3-0"
        case .voxtralMiniLatest:
            return "voxtral-mini-latest"
        }
    }

    var detail: String {
        switch self {
        case .gpt4oTranscribe:
            return "OpenAI flagship transcription model."
        case .gpt4oMiniTranscribeSnapshot:
            return "OpenAI lower-latency snapshot pinned to 2025-12-15."
        case .voxtralMiniTranscribe3:
            return "Mistral Voxtral 3 Mini batch transcription model."
        case .voxtralSmallTranscribe3:
            return "Mistral Voxtral 3 flagship transcription model."
        case .voxtralMiniLatest:
            return "Mistral Voxtral Transcribe 2 (voxtral-mini-2602)."
        }
    }

    var fallbackCandidates: [TranscriptionModel] {
        switch self {
        case .gpt4oTranscribe:
            return [.gpt4oMiniTranscribeSnapshot]
        case .gpt4oMiniTranscribeSnapshot:
            return [.gpt4oTranscribe]
        case .voxtralMiniTranscribe3:
            return [.voxtralSmallTranscribe3, .voxtralMiniLatest]
        case .voxtralSmallTranscribe3:
            return [.voxtralMiniTranscribe3, .voxtralMiniLatest]
        case .voxtralMiniLatest:
            return []
        }
    }

    static func models(for provider: TranscriptionProviderKind) -> [TranscriptionModel] {
        Self.allCases.filter { $0.provider == provider }
    }
}
