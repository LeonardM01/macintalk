import AVFoundation
import Foundation

enum AudioBufferConverterError: Error {
    case failedToCreateConverter
    case conversionFailed
}

final class AudioBufferConverter: @unchecked Sendable {
    private var converter: AVAudioConverter?

    func convert(_ input: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        if converter == nil || converter?.outputFormat != format {
            guard let newConverter = AVAudioConverter(from: input.format, to: format) else {
                throw AudioBufferConverterError.failedToCreateConverter
            }
            converter = newConverter
        }

        guard let converter else {
            throw AudioBufferConverterError.failedToCreateConverter
        }

        let ratio = format.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw AudioBufferConverterError.conversionFailed
        }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return input
        }

        guard status != .error, error == nil else {
            throw AudioBufferConverterError.conversionFailed
        }

        return output
    }
}
