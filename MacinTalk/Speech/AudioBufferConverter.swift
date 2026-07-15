import AVFoundation
import Foundation

enum AudioBufferConverterError: Error {
    case failedToCreateConverter
    case conversionFailed
}

final class AudioBufferConverter: @unchecked Sendable {
    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var outputFormat: AVAudioFormat?

    func reset() {
        lock.lock()
        converter = nil
        inputFormat = nil
        outputFormat = nil
        lock.unlock()
    }

    func convert(_ input: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard input.frameLength > 0 else {
            throw AudioBufferConverterError.conversionFailed
        }

        if formatsMatch(input.format, format) {
            return input
        }

        lock.lock()
        let needsNewConverter = converter == nil
            || !formatsMatch(inputFormat, input.format)
            || !formatsMatch(outputFormat, format)

        if needsNewConverter {
            guard let newConverter = AVAudioConverter(from: input.format, to: format) else {
                lock.unlock()
                throw AudioBufferConverterError.failedToCreateConverter
            }
            converter = newConverter
            inputFormat = input.format
            outputFormat = format
        }

        guard let converter else {
            lock.unlock()
            throw AudioBufferConverterError.failedToCreateConverter
        }
        lock.unlock()

        let ratio = format.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw AudioBufferConverterError.conversionFailed
        }

        var consumed = false
        var error: NSError?
        let inputBuffer = input
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        guard status != .error, error == nil, output.frameLength > 0 else {
            throw AudioBufferConverterError.conversionFailed
        }

        return output
    }

    private func formatsMatch(_ lhs: AVAudioFormat?, _ rhs: AVAudioFormat?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            true
        case let (left?, right?):
            left.isEqual(right)
        default:
            false
        }
    }
}
