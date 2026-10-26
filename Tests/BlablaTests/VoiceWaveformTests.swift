import Testing
@testable import BlablaApp

struct VoiceWaveformTests {
    @Test
    func risesImmediatelyWithLouderInput() {
        #expect(VoiceWaveform.smoothed(0.2, toward: 0.8) == 0.8)
    }

    @Test
    func decaysGraduallyWhenInputDrops() {
        let next = VoiceWaveform.smoothed(0.8, toward: 0)
        #expect(next < 0.8)
        #expect(next > 0.6)
    }

    @Test
    func loudnessIgnoresRoomNoiseAndFillsForNormalSpeech() {
        #expect(VoiceWaveform.loudness(0.1) == 0)
        #expect(VoiceWaveform.loudness(0.5) > 0.6)
        #expect(VoiceWaveform.loudness(0.8) == 1)
    }
}
