import Foundation

struct TranscriptionResult: Equatable {
    let text: String
    let provider: TranscriptionProviderKind
    let model: TranscriptionModel
    let languageCode: String
}

enum TranscriptionServiceError: LocalizedError {
    case missingAPIKey(TranscriptionProviderKind)
    case invalidModelSelection
    case fileReadFailed
    case transportFailure(String, retryable: Bool)
    case badStatus(code: Int, message: String, retryable: Bool)
    case emptyTranscript
    case allFallbacksFailed([String])

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider.displayName) API key is not configured."
        case .invalidModelSelection:
            return "The selected model is not compatible with the configured provider."
        case .fileReadFailed:
            return "The audio recording could not be prepared for upload."
        case .transportFailure(let message, _):
            return message
        case .badStatus(_, let message, _):
            return message
        case .emptyTranscript:
            return "The transcription API returned an empty transcript."
        case .allFallbacksFailed(let reasons):
            return reasons.joined(separator: "\n")
        }
    }

    var isRetryable: Bool {
        switch self {
        case .transportFailure(_, let retryable), .badStatus(_, _, let retryable):
            return retryable
        default:
            return false
        }
    }
}

final class TranscriptionService: @unchecked Sendable {
    private let keychain: KeychainService
    private let session: URLSession

    init(keychain: KeychainService, session: URLSession? = nil) {
        self.keychain = keychain

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 90
            configuration.timeoutIntervalForResource = 180
            self.session = URLSession(configuration: configuration)
        }
    }

    func hasAPIKey(for provider: TranscriptionProviderKind) -> Bool {
        keychain.hasValue(account: provider.keychainAccount)
    }

    func transcribe(
        audioFileURL: URL,
        provider: TranscriptionProviderKind,
        selectedModel: TranscriptionModel,
        languageCode: String
    ) async throws -> TranscriptionResult {
        guard selectedModel.provider == provider else {
            throw TranscriptionServiceError.invalidModelSelection
        }

        guard let apiKey = try keychain.read(account: provider.keychainAccount),
              !apiKey.isEmpty else {
            throw TranscriptionServiceError.missingAPIKey(provider)
        }

        let candidates = [selectedModel] + selectedModel.fallbackCandidates.filter { $0.provider == provider }
        var fallbackFailures: [String] = []

        for (index, candidate) in candidates.enumerated() {
            do {
                return try await transcribeWithRetries(
                    audioFileURL: audioFileURL,
                    provider: provider,
                    model: candidate,
                    languageCode: languageCode,
                    apiKey: apiKey
                )
            } catch let error as TranscriptionServiceError {
                let failureSummary = "\(candidate.displayName): \(error.localizedDescription)"
                if error.isRetryable, index < candidates.count - 1 {
                    fallbackFailures.append(failureSummary)
                    continue
                }

                if !fallbackFailures.isEmpty {
                    fallbackFailures.append(failureSummary)
                    throw TranscriptionServiceError.allFallbacksFailed(fallbackFailures)
                }

                throw error
            } catch {
                throw error
            }
        }

        throw TranscriptionServiceError.allFallbacksFailed(fallbackFailures)
    }

    private func transcribeWithRetries(
        audioFileURL: URL,
        provider: TranscriptionProviderKind,
        model: TranscriptionModel,
        languageCode: String,
        apiKey: String
    ) async throws -> TranscriptionResult {
        let retryBackoffNanoseconds: [UInt64] = [
            350_000_000,
            1_000_000_000,
        ]

        for attempt in 0...retryBackoffNanoseconds.count {
            do {
                return try await transcribeOnce(
                    audioFileURL: audioFileURL,
                    provider: provider,
                    model: model,
                    languageCode: languageCode,
                    apiKey: apiKey
                )
            } catch let error as TranscriptionServiceError where error.isRetryable && attempt < retryBackoffNanoseconds.count {
                try await Task.sleep(nanoseconds: retryBackoffNanoseconds[attempt])
            } catch {
                throw error
            }
        }

        throw TranscriptionServiceError.transportFailure("The transcription request exhausted its retry budget.", retryable: true)
    }

    private func transcribeOnce(
        audioFileURL: URL,
        provider: TranscriptionProviderKind,
        model: TranscriptionModel,
        languageCode: String,
        apiKey: String
    ) async throws -> TranscriptionResult {
        let request: URLRequest
        switch provider {
        case .openAI:
            request = try makeOpenAIRequest(audioFileURL: audioFileURL, model: model, languageCode: languageCode, apiKey: apiKey)
        case .mistral:
            request = try makeMistralRequest(audioFileURL: audioFileURL, model: model, languageCode: languageCode, apiKey: apiKey)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TranscriptionServiceError.transportFailure(
                "The transcription request failed before receiving a response: \(error.localizedDescription)",
                retryable: true
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionServiceError.transportFailure("The transcription API returned a non-HTTP response.", retryable: true)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = extractErrorMessage(from: data) ?? "The transcription API returned HTTP \(httpResponse.statusCode)."
            let retryable = httpResponse.statusCode == 429 || (500..<600).contains(httpResponse.statusCode)
            throw TranscriptionServiceError.badStatus(code: httpResponse.statusCode, message: message, retryable: retryable)
        }

        guard let transcript = extractTranscript(from: data), !transcript.isEmpty else {
            throw TranscriptionServiceError.emptyTranscript
        }

        return TranscriptionResult(
            text: transcript,
            provider: provider,
            model: model,
            languageCode: languageCode
        )
    }

    private func makeOpenAIRequest(
        audioFileURL: URL,
        model: TranscriptionModel,
        languageCode: String,
        apiKey: String
    ) throws -> URLRequest {
        guard model.provider == .openAI else {
            throw TranscriptionServiceError.invalidModelSelection
        }

        var builder = MultipartFormDataBuilder()
        builder.addTextField(name: "model", value: model.rawValue)
        builder.addTextField(name: "response_format", value: "json")
        if !languageCode.isEmpty {
            builder.addTextField(name: "language", value: languageCode)
        }

        do {
            try builder.addFileField(name: "file", fileURL: audioFileURL)
        } catch {
            throw TranscriptionServiceError.fileReadFailed
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(builder.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = builder.finalize()
        return request
    }

    private func makeMistralRequest(
        audioFileURL: URL,
        model: TranscriptionModel,
        languageCode: String,
        apiKey: String
    ) throws -> URLRequest {
        guard model.provider == .mistral else {
            throw TranscriptionServiceError.invalidModelSelection
        }

        var builder = MultipartFormDataBuilder()
        builder.addTextField(name: "model", value: model.rawValue)
        if !languageCode.isEmpty {
            builder.addTextField(name: "language", value: languageCode)
        }

        do {
            try builder.addFileField(name: "file", fileURL: audioFileURL)
        } catch {
            throw TranscriptionServiceError.fileReadFailed
        }

        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(builder.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = builder.finalize()
        return request
    }

    private func extractTranscript(from data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let text = object["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let transcription = object["transcription"] as? String {
                return transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let outputText = object["output_text"] as? String {
                return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractErrorMessage(from data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = object["message"] as? String {
                return message
            }
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
            if let detail = object["detail"] as? String {
                return detail
            }
        }

        let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return string?.isEmpty == false ? string : nil
    }
}
