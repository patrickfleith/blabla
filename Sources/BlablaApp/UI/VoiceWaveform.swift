import SwiftUI

struct VoiceWaveform: View {
    let level: Double

    @State private var displayedLevel = 0.0

    private static let barCount = 14

    // Rise instantly with the voice, fall back gradually so the bars don't flicker between buffers.
    nonisolated static func smoothed(_ current: Double, toward target: Double) -> Double {
        target > current ? target : current * 0.85 + target * 0.15
    }

    // The meter spans -55...0 dBFS, but speech on a laptop mic sits around -45...-20 dBFS.
    // Stretch that band to the full bar height so normal speech fills the waveform.
    nonisolated static func loudness(_ level: Double) -> Double {
        min(max((level - 0.15) / 0.5, 0), 1)
    }

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<Self.barCount, id: \.self) { index in
                    Capsule()
                        .frame(width: 3, height: barHeight(index: index, time: time))
                }
            }
        }
        .foregroundStyle(Color.primary.opacity(0.75))
        .frame(maxWidth: .infinity)
        .onChange(of: level) { _, newLevel in
            displayedLevel = Self.smoothed(displayedLevel, toward: newLevel)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let center = Double(Self.barCount - 1) / 2
        let envelope = 1 - 0.7 * abs(Double(index) - center) / center
        let wobble = 0.6 + 0.4 * sin(time * 9 + Double(index) * 1.3)
        return 3 + 27 * Self.loudness(displayedLevel) * envelope * wobble
    }
}
