import Testing
@testable import BlablaApp

struct TranscriptionModelTests {
    @Test
    func openAIFallbackOrderIsStable() {
        #expect(TranscriptionModel.gpt4oTranscribe.fallbackCandidates == [.gpt4oMiniTranscribeSnapshot])
        #expect(TranscriptionModel.gpt4oMiniTranscribeSnapshot.fallbackCandidates == [.gpt4oTranscribe])
    }

    @Test
    func mistralFallbackOrderIsStable() {
        #expect(
            TranscriptionModel.voxtralMiniTranscribe3.fallbackCandidates == [.voxtralSmallTranscribe3, .voxtralMiniLatest]
        )
        #expect(
            TranscriptionModel.voxtralSmallTranscribe3.fallbackCandidates == [.voxtralMiniTranscribe3, .voxtralMiniLatest]
        )
        #expect(TranscriptionModel.voxtralMiniLatest.fallbackCandidates.isEmpty)
    }

    @Test
    func providerModelFilteringReturnsOnlyCompatibleModels() {
        #expect(
            TranscriptionModel.models(for: .openAI) == [.gpt4oTranscribe, .gpt4oMiniTranscribeSnapshot]
        )
        #expect(
            TranscriptionModel.models(for: .mistral) == [.voxtralMiniTranscribe3, .voxtralSmallTranscribe3, .voxtralMiniLatest]
        )
    }
}
