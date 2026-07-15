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
    case noSpeechDetected
    case audioConversionFailed(String)
    case speechRecognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .localeNotSupported:
            "Speech recognition is not supported for the selected locale."
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
        case .noSpeechDetected:
            "No speech was detected."
        case .audioConversionFailed(let message):
            "Could not convert microphone audio for speech recognition: \(message)"
        case .speechRecognitionFailed(let message):
            "Speech recognition failed: \(message)"
        }
    }
}

final class SpeechAudioPipelineState: @unchecked Sendable {
    private let lock = NSLock()
    private var receivedSample = false
    private var conversionFailure: Error?

    func reset() {
        lock.withLock {
            receivedSample = false
            conversionFailure = nil
        }
    }

    func noteSuccessfulSample() {
        lock.withLock {
            receivedSample = true
        }
    }

    func noteConversionFailure(_ error: Error) {
        lock.withLock {
            if conversionFailure == nil {
                conversionFailure = error
            }
        }
    }

    func snapshot() -> (receivedSample: Bool, conversionFailure: Error?) {
        lock.withLock {
            (receivedSample, conversionFailure)
        }
    }
}

@MainActor
final class SpeechAnalyzerService: SpeechTranscribing {
    private(set) var stableText = ""
    private(set) var volatileText = ""

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Error>?
    private var analyzerFormat: AVAudioFormat?
    private var isRecording = false
    private let bufferConverter = AudioBufferConverter()
    private let microphoneCapture = MicrophoneCapture()
    private let settings: AppSettings
    private let preferredLocale: Locale
    private var activeLocale: Locale?
    private var audioPipelineState = SpeechAudioPipelineState()

    init(preferredLocale: Locale = .current, settings: AppSettings) {
        self.preferredLocale = preferredLocale
        self.settings = settings
    }

    var resolvedLocale: Locale? {
        activeLocale
    }

    func prepare() async throws {
        let resolution = await SpeechLocaleResolver.resolve(preferred: preferredLocale)
        activeLocale = resolution.locale

        let transcriber = SpeechTranscriber(
            locale: resolution.locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )

        try await ensureModel(for: transcriber, locale: resolution.locale)
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        guard analyzerFormat != nil else {
            throw SpeechServiceError.invalidAudioFormat
        }
    }

    func startRecording() async throws {
        if isRecording {
            await cancelRecording()
        }

        if analyzerFormat == nil || activeLocale == nil {
            try await prepare()
        }

        guard let locale = activeLocale, let analyzerFormat else {
            throw SpeechServiceError.analyzerUnavailable
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.transcriber = transcriber
        self.analyzer = analyzer

        stableText = ""
        volatileText = ""
        audioPipelineState.reset()

        let granted = await requestMicrophoneAccess()
        guard granted else { throw SpeechServiceError.microphoneDenied }

        bufferConverter.reset()

        let (inputSequence, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation

        resultsTask = Task { [weak self] in
            guard let self else { return }
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
        }

        do {
            try await analyzer.start(inputSequence: inputSequence)
        } catch {
            await releaseSessionAfterStartFailure()
            throw error
        }

        isRecording = true

        do {
            try startMicrophoneCapture()
        } catch {
            await cancelRecording()
            throw error
        }
    }

    func stopRecording() async throws -> String {
        guard isRecording, analyzer != nil else { throw SpeechServiceError.notRecording }

        let transcript = try await finalizeActiveSession(requireTranscript: true, cancelled: false)
        stableText = transcript
        volatileText = ""
        return transcript
    }

    private func cancelRecording() async {
        guard isRecording || analyzer != nil else { return }
        _ = try? await finalizeActiveSession(requireTranscript: false, cancelled: true)
        stableText = ""
        volatileText = ""
    }

    private func releaseSessionAfterStartFailure() async {
        inputContinuation?.finish()
        inputContinuation = nil

        if let analyzer {
            await analyzer.cancelAndFinishNow()
        }

        resultsTask?.cancel()
        if let resultsTask {
            _ = try? await resultsTask.value
        }

        clearSessionReferences()
    }

    private func finalizeActiveSession(requireTranscript: Bool, cancelled: Bool) async throws -> String {
        microphoneCapture.stop()
        inputContinuation?.finish()
        inputContinuation = nil

        var finalizeError: Error?
        if let analyzer {
            do {
                if cancelled {
                    await analyzer.cancelAndFinishNow()
                } else {
                    try await analyzer.finalizeAndFinishThroughEndOfInput()
                }
            } catch {
                finalizeError = error
            }
        }

        var resultStreamError: Error?
        if let resultsTask {
            do {
                try await resultsTask.value
            } catch {
                if !Task.isCancelled {
                    resultStreamError = error
                }
            }
        }

        let transcript = (stableText + volatileText).trimmingCharacters(in: .whitespacesAndNewlines)
        let pipeline = audioPipelineState.snapshot()

        clearSessionReferences()

        guard requireTranscript else { return "" }

        if let resultStreamError {
            throw SpeechServiceError.speechRecognitionFailed(resultStreamError.localizedDescription)
        }

        if let finalizeError {
            throw SpeechServiceError.speechRecognitionFailed(finalizeError.localizedDescription)
        }

        if let conversionFailure = pipeline.conversionFailure,
           !pipeline.receivedSample,
           transcript.isEmpty {
            throw SpeechServiceError.audioConversionFailed(conversionFailure.localizedDescription)
        }

        if !pipeline.receivedSample && transcript.isEmpty {
            throw SpeechServiceError.noSpeechDetected
        }

        return transcript
    }

    private func clearSessionReferences() {
        resultsTask = nil
        transcriber = nil
        analyzer = nil
        isRecording = false
        audioPipelineState.reset()
    }

    private func startMicrophoneCapture() throws {
        guard let analyzerFormat, let continuation = inputContinuation else {
            throw SpeechServiceError.invalidAudioFormat
        }

        let converter = bufferConverter
        let pipelineState = audioPipelineState
        microphoneCapture.setSelectedDeviceID(settings.selectedInputDeviceID)
        try microphoneCapture.start { buffer in
            do {
                let converted = try converter.convert(buffer, to: analyzerFormat)
                pipelineState.noteSuccessfulSample()
                continuation.yield(AnalyzerInput(buffer: converted))
            } catch {
                pipelineState.noteConversionFailure(error)
            }
        }
    }

    private func ensureModel(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        let supported = await SpeechTranscriber.supportedLocales
        let localeID = locale.identifier(.bcp47)
        guard supported.map({ $0.identifier(.bcp47) }).contains(localeID) else {
            throw SpeechServiceError.localeNotSupported
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
    static func localeResolution(preferred: Locale = .current) async -> SpeechLocaleResolution {
        await SpeechLocaleResolver.resolve(preferred: preferred)
    }

    static func assetsInstalled(for locale: Locale) async -> Bool {
        let installed = Set(await SpeechTranscriber.installedLocales)
        return installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }
}
