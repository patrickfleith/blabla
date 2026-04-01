@preconcurrency import AVFoundation
import CoreMedia
import Foundation

struct RecordingArtifact {
    let fileURL: URL
    let duration: TimeInterval
}

enum AudioCaptureServiceError: LocalizedError {
    case microphonePermissionDenied
    case noInputDevice
    case alreadyRecording
    case notRecording
    case writerFailure(String)
    case emptyRecording

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required before recording can start."
        case .noInputDevice:
            return "No usable audio input device is available."
        case .alreadyRecording:
            return "A recording is already in progress."
        case .notRecording:
            return "No recording is currently in progress."
        case .writerFailure(let message):
            return "Audio capture failed: \(message)"
        case .emptyRecording:
            return "The recording did not contain any audio samples."
        }
    }
}

final class AudioCaptureService: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    var onMeterLevelChanged: ((Double) -> Void)?
    var onElapsedTimeChanged: ((TimeInterval) -> Void)?

    private let captureQueue = DispatchQueue(label: "com.astro.blabla.audio-capture")
    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var assetWriter: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var recordingURL: URL?
    private var recordingStartedAt: Date?
    private var elapsedTimer: DispatchSourceTimer?
    private var latestDuration: TimeInterval = 0
    private var didReceiveSample = false
    private var hasStartedWriterSession = false

    func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func availableMicrophones(selectedID _: String? = nil) -> [MicrophoneDevice] {
        let defaultID = AVCaptureDevice.default(for: .audio)?.uniqueID

        return discoveredAudioDevices()
            .map { device in
                MicrophoneDevice(
                    id: device.uniqueID,
                    name: device.localizedName,
                    isDefault: device.uniqueID == defaultID
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDefault != rhs.isDefault {
                    return lhs.isDefault
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func startRecording(deviceID: String?, maximumDuration _: TimeInterval) async throws {
        let permissionGranted = await requestPermission()
        guard permissionGranted else {
            throw AudioCaptureServiceError.microphonePermissionDenied
        }

        try await withCheckedThrowingContinuation { continuation in
            captureQueue.async {
                do {
                    guard self.captureSession == nil else {
                        throw AudioCaptureServiceError.alreadyRecording
                    }

                    let device = self.discoveredAudioDevices().first(where: { $0.uniqueID == deviceID })
                        ?? AVCaptureDevice.default(for: .audio)
                    guard let device else {
                        throw AudioCaptureServiceError.noInputDevice
                    }

                    let session = AVCaptureSession()
                    session.beginConfiguration()

                    let input = try AVCaptureDeviceInput(device: device)
                    guard session.canAddInput(input) else {
                        throw AudioCaptureServiceError.noInputDevice
                    }
                    session.addInput(input)

                    let output = AVCaptureAudioDataOutput()
                    output.setSampleBufferDelegate(self, queue: self.captureQueue)
                    guard session.canAddOutput(output) else {
                        throw AudioCaptureServiceError.noInputDevice
                    }
                    session.addOutput(output)
                    session.commitConfiguration()

                    let recordingURL = try self.makeRecordingURL()
                    let writer = try AVAssetWriter(url: recordingURL, fileType: .m4a)
                    let outputSettings = output.recommendedAudioSettingsForAssetWriter(writingTo: .m4a)
                        ?? self.defaultAudioSettings()
                    let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
                    writerInput.expectsMediaDataInRealTime = true
                    guard writer.canAdd(writerInput) else {
                        throw AudioCaptureServiceError.writerFailure("The AAC writer input could not be attached.")
                    }
                    writer.add(writerInput)

                    self.captureSession = session
                    self.audioOutput = output
                    self.assetWriter = writer
                    self.writerInput = writerInput
                    self.recordingURL = recordingURL
                    self.recordingStartedAt = Date()
                    self.latestDuration = 0
                    self.didReceiveSample = false
                    self.hasStartedWriterSession = false
                    self.startElapsedTimer()

                    session.startRunning()
                    continuation.resume()
                } catch {
                    self.resetState(removeFile: true)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stopRecording() async throws -> RecordingArtifact {
        try await withCheckedThrowingContinuation { continuation in
            captureQueue.async {
                guard let session = self.captureSession,
                      let output = self.audioOutput,
                      let writer = self.assetWriter,
                      let writerInput = self.writerInput,
                      let recordingURL = self.recordingURL else {
                    continuation.resume(throwing: AudioCaptureServiceError.notRecording)
                    return
                }

                self.stopElapsedTimer()
                output.setSampleBufferDelegate(nil, queue: nil)
                session.stopRunning()

                self.captureSession = nil
                self.audioOutput = nil

                guard self.didReceiveSample, self.hasStartedWriterSession else {
                    self.resetState(removeFile: true)
                    continuation.resume(throwing: AudioCaptureServiceError.emptyRecording)
                    return
                }

                let duration = self.latestDuration
                writerInput.markAsFinished()
                writer.finishWriting {
                    self.captureQueue.async {
                        if writer.status == .completed {
                            self.resetState(removeFile: false)
                            continuation.resume(returning: RecordingArtifact(fileURL: recordingURL, duration: duration))
                        } else {
                            let message = writer.error?.localizedDescription ?? "Unknown writer error."
                            self.resetState(removeFile: true)
                            continuation.resume(throwing: AudioCaptureServiceError.writerFailure(message))
                        }
                    }
                }
            }
        }
    }

    func shutdown() {
        captureQueue.sync {
            stopElapsedTimer()
            audioOutput?.setSampleBufferDelegate(nil, queue: nil)
            captureSession?.stopRunning()
            resetState(removeFile: false)
        }
    }

    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard let writer = assetWriter,
              let writerInput,
              writer.status != .failed else {
            return
        }

        didReceiveSample = true

        if !hasStartedWriterSession {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startWriting()
            writer.startSession(atSourceTime: timestamp)
            hasStartedWriterSession = true
        }

        if writerInput.isReadyForMoreMediaData {
            writerInput.append(sampleBuffer)
        }

        let meterLevel = normalizedMeterLevel(from: sampleBuffer)
        DispatchQueue.main.async {
            self.onMeterLevelChanged?(meterLevel)
        }
    }

    private func startElapsedTimer() {
        stopElapsedTimer()

        let timer = DispatchSource.makeTimerSource(queue: captureQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self,
                  let recordingStartedAt = self.recordingStartedAt else {
                return
            }

            self.latestDuration = Date().timeIntervalSince(recordingStartedAt)
            let duration = self.latestDuration
            DispatchQueue.main.async {
                self.onElapsedTimeChanged?(duration)
            }
        }
        elapsedTimer = timer
        timer.resume()
    }

    private func stopElapsedTimer() {
        elapsedTimer?.cancel()
        elapsedTimer = nil
    }

    private func makeRecordingURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("blabla-recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
    }

    private func discoveredAudioDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }

    private func defaultAudioSettings() -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 24_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ]
    }

    private func resetState(removeFile: Bool) {
        let fileURL = recordingURL

        captureSession = nil
        audioOutput = nil
        assetWriter = nil
        writerInput = nil
        recordingURL = nil
        recordingStartedAt = nil
        latestDuration = 0
        didReceiveSample = false
        hasStartedWriterSession = false

        DispatchQueue.main.async {
            self.onElapsedTimeChanged?(0)
            self.onMeterLevelChanged?(0)
        }

        if removeFile, let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func normalizedMeterLevel(from sampleBuffer: CMSampleBuffer) -> Double {
        var bufferListSizeNeeded = 0
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &bufferListSizeNeeded,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
            blockBufferOut: nil
        )

        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: bufferListSizeNeeded, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer {
            rawPointer.deallocate()
        }

        let bufferList = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: bufferList,
            bufferListSize: bufferListSizeNeeded,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
            blockBufferOut: &blockBuffer
        )
        guard status == noErr,
              let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else {
            return 0
        }

        let audioBuffers = UnsafeMutableAudioBufferListPointer(bufferList)
        var sumSquares = 0.0
        var sampleCount = 0

        for audioBuffer in audioBuffers {
            guard let data = audioBuffer.mData else {
                continue
            }

            if streamDescription.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                let count = Int(audioBuffer.mDataByteSize) / MemoryLayout<Float>.size
                let samples = data.assumingMemoryBound(to: Float.self)
                for index in 0..<count {
                    let sample = Double(samples[index])
                    sumSquares += sample * sample
                }
                sampleCount += count
            } else if streamDescription.mBitsPerChannel == 16 {
                let count = Int(audioBuffer.mDataByteSize) / MemoryLayout<Int16>.size
                let samples = data.assumingMemoryBound(to: Int16.self)
                for index in 0..<count {
                    let sample = Double(samples[index]) / Double(Int16.max)
                    sumSquares += sample * sample
                }
                sampleCount += count
            } else if streamDescription.mBitsPerChannel == 32 {
                let count = Int(audioBuffer.mDataByteSize) / MemoryLayout<Int32>.size
                let samples = data.assumingMemoryBound(to: Int32.self)
                for index in 0..<count {
                    let sample = Double(samples[index]) / Double(Int32.max)
                    sumSquares += sample * sample
                }
                sampleCount += count
            }
        }

        guard sampleCount > 0 else {
            return 0
        }

        let rms = sqrt(sumSquares / Double(sampleCount))
        let decibels = 20 * log10(max(rms, 0.000_01))
        return max(0, min(1, (decibels + 55) / 55))
    }
}
