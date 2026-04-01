import AVFoundation
import Foundation

enum FeedbackTone {
    case start
    case stop
    case success
}

final class SoundFeedbackService {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let mixer = AVAudioMixerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    var volume: Double {
        didSet {
            mixer.outputVolume = Float(clamp(volume))
        }
    }

    init(volume: Double = 0.7) {
        self.volume = Self.clamp(volume)

        guard let format else {
            return
        }

        engine.attach(player)
        engine.attach(mixer)
        engine.connect(player, to: mixer, format: format)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)
        mixer.outputVolume = Float(clamp(volume))

        do {
            try engine.start()
        } catch {
            // Ignore audio feedback failures; the app still works without tones.
        }
    }

    func play(_ tone: FeedbackTone) {
        guard let format else {
            return
        }

        if !engine.isRunning {
            try? engine.start()
        }

        let buffer = makeBuffer(for: tone, format: format)
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func clamp(_ value: Double) -> Double {
        Self.clamp(value)
    }

    private func makeBuffer(for tone: FeedbackTone, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sequence: [(frequency: Double, duration: Double, amplitude: Double)] = switch tone {
        case .start:
            [(640, 0.05, 0.35), (880, 0.09, 0.38)]
        case .stop:
            [(760, 0.05, 0.32), (580, 0.11, 0.35)]
        case .success:
            [(523.25, 0.05, 0.32), (659.25, 0.05, 0.34), (783.99, 0.14, 0.38)]
        }

        let sampleRate = format.sampleRate
        let totalFrames = sequence.reduce(0) { partial, segment in
            partial + Int(segment.duration * sampleRate)
        }
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames))!
        buffer.frameLength = AVAudioFrameCount(totalFrames)

        guard let channelData = buffer.floatChannelData?[0] else {
            return buffer
        }

        var frameCursor = 0
        for segment in sequence {
            let frameCount = Int(segment.duration * sampleRate)
            for frame in 0..<frameCount {
                let progress = Double(frame) / Double(frameCount)
                let attack = min(progress / 0.12, 1)
                let release = min((1 - progress) / 0.18, 1)
                let envelope = Float(min(attack, release))
                let sampleIndex = frameCursor + frame
                let time = Double(sampleIndex) / sampleRate
                let sample = sin(2 * Double.pi * segment.frequency * time)
                channelData[sampleIndex] = Float(sample) * Float(segment.amplitude) * envelope
            }
            frameCursor += frameCount
        }

        return buffer
    }
}
