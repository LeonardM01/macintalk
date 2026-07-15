import AVFoundation
import Foundation
import Speech

enum SpeechServiceError: LocalizedError {
    case localeNotSupported
    case modelInstallFailed(String)
    case microphoneDenied
    case invalidAudioFormat
    case notRecording
    case analyzerUnavailable

    var errorDescription: String? {
        switch self {
        case .localeNotSupported:
            "Speech recognition is not supported for the current locale."
        case .modelInstallFailed(let message):
            "Failed to install speech assets: \(message)"
        case .microphoneDenied:
            "Microphone access was denied."
        case .invalidAudioFormat:
            "Could not determine a compatible audio format."
        case .notRecording:
            "No active recording session."
        case .analyzerUnavailable:
            "Speech analyzer is not available."
        }
    }
}

@MainActor
final class SpeechAnalyzerService: SpeechTranscribing {
    private(set) var stableText = ""
    private(set) var volatileText = ""

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var audioEngine: AVAudioEngine?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var analyzerFormat: AVAudioFormat?
    private let bufferConverter = AudioBufferConverter()
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func prepare() async throws {
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )

        try await ensureModel(for: transcriber)

        self.transcriber = transcriber
        self.analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        guard analyzerFormat != nil else {
            throw SpeechServiceError.invalidAudioFormat
        }
    }

    func startRecording() async throws {
        guard let transcriber, let analyzer else {
            try await prepare()
            return try await startRecording()
        }

        stableText = ""
        volatileText = ""

        let granted = await requestMicrophoneAccess()
        guard granted else { throw SpeechServiceError.microphoneDenied }

        let (inputSequence, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation

        resultsTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    let text = TranscriptAssembler.attributedStringText(result.text)
                    if result.isFinal {
                        await MainActor.run {
                            self.stableText = TranscriptAssembler.appendFinal(self.stableText, finalText: text)
                            self.volatileText = ""
                        }
                    } else {
                        await MainActor.run {
                            self.volatileText = text
                        }
                    }
                }
            } catch {
                // Results stream ends when analyzer finalizes.
            }
        }

        try await analyzer.start(inputSequence: inputSequence)
        try startAudioCapture()
    }

    func stopRecording() async throws -> String {
        guard let analyzer else { throw SpeechServiceError.notRecording }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        inputContinuation?.finish()
        inputContinuation = nil

        try await analyzer.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()
        resultsTask = nil

        let transcript = (stableText + volatileText).trimmingCharacters(in: .whitespacesAndNewlines)
        stableText = transcript
        volatileText = ""
        return transcript
    }

    private func startAudioCapture() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let analyzerFormat else {
            throw SpeechServiceError.invalidAudioFormat
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let continuation = self.inputContinuation else { return }
            do {
                let converted = try self.bufferConverter.convert(buffer, to: analyzerFormat)
                continuation.yield(AnalyzerInput(buffer: converted))
            } catch {
                // Drop frames that cannot be converted.
            }
        }

        engine.prepare()
        try engine.start()
        audioEngine = engine
    }

    private func ensureModel(for transcriber: SpeechTranscriber) async throws {
        let supported = await SpeechTranscriber.supportedLocales
        let localeID = locale.identifier(.bcp47)
        guard supported.map({ $0.identifier(.bcp47) }).contains(localeID) else {
            throw SpeechServiceError.localeNotSupported
        }

        let installed = Set(await SpeechTranscriber.installedLocales)
        if installed.map({ $0.identifier(.bcp47) }).contains(localeID) {
            return
        }

        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            do {
                try await request.downloadAndInstall()
            } catch {
                throw SpeechServiceError.modelInstallFailed(error.localizedDescription)
            }
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }
}

enum SpeechReadinessChecker {
    static func localeSupported(_ locale: Locale = .current) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        return supported.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }

    static func assetsInstalled(_ locale: Locale = .current) async -> Bool {
        let installed = Set(await SpeechTranscriber.installedLocales)
        return installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }
}
