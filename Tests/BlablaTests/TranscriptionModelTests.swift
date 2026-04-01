import Testing
@testable import BlablaApp

struct TranscriptionModelTests {
    @Test
    func openAIFallbackOrderIsStable() {
        #expect(TranscriptionModel.gpt4oTranscribe.fallbackCandidates == [.gpt4oMiniTranscribeSnapshot])
        #expect(TranscriptionModel.gpt4oMiniTranscribeSnapshot.fallbackCandidates == [.gpt4oTranscribe])
    }

    @Test
    func providerModelFilteringReturnsOnlyCompatibleModels() {
        #expect(
            TranscriptionModel.models(for: .openAI) == [.gpt4oTranscribe, .gpt4oMiniTranscribeSnapshot]
        )
        #expect(
            TranscriptionModel.models(for: .mistral) == [.voxtralMiniLatest]
        )
    }
}
