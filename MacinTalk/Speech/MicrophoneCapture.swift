import AVFoundation
import CoreMedia
import Foundation

enum CMSampleBufferConverter {
    static func makePCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription),
              let format = AVAudioFormat(streamDescription: streamDescription) else {
            return nil
        }

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frameCount > 0,
              let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        pcmBuffer.frameLength = frameCount
        let copyStatus = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: pcmBuffer.mutableAudioBufferList
        )
        guard copyStatus == noErr else { return nil }
        return pcmBuffer
    }
}

final class MicrophoneCapture: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    static let defaultDeviceConfigurationKey = "__system_default__"

    private let session = AVCaptureSession()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "MacinTalk.MicrophoneCapture", qos: .userInitiated)
    private let stateLock = NSLock()
    private var bufferHandler: (@Sendable (AVAudioPCMBuffer) -> Void)?
    private var selectedDeviceID: String?
    private var configuredDeviceKey: String?
    private var isRunning = false

    var isConfigured: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return configuredDeviceKey != nil
    }

    static func configurationKey(for deviceID: String?) -> String {
        deviceID ?? defaultDeviceConfigurationKey
    }

    static func needsConfiguration(configuredKey: String?, selectedDeviceID: String?) -> Bool {
        configuredKey != configurationKey(for: selectedDeviceID)
    }

    func setSelectedDeviceID(_ deviceID: String?) {
        let normalized = deviceID.flatMap { $0.isEmpty ? nil : $0 }
        stateLock.lock()
        let changed = selectedDeviceID != normalized
        selectedDeviceID = normalized
        stateLock.unlock()

        guard changed else { return }
        invalidateConfiguration()
    }

    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        stateLock.lock()
        bufferHandler = onBuffer
        let deviceID = selectedDeviceID
        let needsConfiguration = Self.needsConfiguration(
            configuredKey: configuredDeviceKey,
            selectedDeviceID: deviceID
        )
        stateLock.unlock()

        if needsConfiguration {
            try configureSession(deviceID: deviceID)
            stateLock.lock()
            configuredDeviceKey = Self.configurationKey(for: deviceID)
            stateLock.unlock()
        }

        guard !isRunning else { return }

        if !session.isRunning {
            session.startRunning()
        }
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }

        if session.isRunning {
            session.stopRunning()
        }
        isRunning = false

        stateLock.lock()
        bufferHandler = nil
        stateLock.unlock()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        stateLock.lock()
        let handler = bufferHandler
        stateLock.unlock()

        guard let handler,
              let pcmBuffer = CMSampleBufferConverter.makePCMBuffer(from: sampleBuffer) else {
            return
        }
        handler(pcmBuffer)
    }

    private func invalidateConfiguration() {
        if isRunning {
            stop()
        }
        stateLock.lock()
        configuredDeviceKey = nil
        stateLock.unlock()
    }

    private func configureSession(deviceID: String?) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }

        guard let microphone = AudioInputDeviceDiscovery.captureDevice(for: deviceID) else {
            throw SpeechServiceError.microphoneDenied
        }

        let input = try AVCaptureDeviceInput(device: microphone)
        guard session.canAddInput(input) else {
            throw SpeechServiceError.invalidAudioFormat
        }
        session.addInput(input)

        audioOutput.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(audioOutput) else {
            throw SpeechServiceError.invalidAudioFormat
        }
        session.addOutput(audioOutput)
    }
}
