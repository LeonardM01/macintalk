import Foundation

enum DictationPhase: Equatable, Sendable {
    case idle
    case recording
    case cleaning
    case inserting
    case failed(DictationFailure)
}

enum DictationFailure: Equatable, Sendable, LocalizedError {
    case microphoneDenied
    case inputMonitoringDenied
    case postEventDenied
    case speechAssetsUnavailable
    case localeUnsupported
    case appleIntelligenceUnavailable
    case emptyTranscript
    case speechRecognitionFailed(String)
    case insertionFailed(String)
    case notReady(String)

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Microphone access is required for dictation."
        case .inputMonitoringDenied:
            "Input Monitoring permission is required for the global hotkey."
        case .postEventDenied:
            "Accessibility permission is required to paste text into other apps."
        case .speechAssetsUnavailable:
            "Speech recognition assets are not available for your locale."
        case .localeUnsupported:
            "Your current locale is not supported by SpeechTranscriber."
        case .appleIntelligenceUnavailable:
            "Apple Intelligence is unavailable. Raw transcripts will be used."
        case .emptyTranscript:
            "No speech was detected."
        case .speechRecognitionFailed(let message):
            "Speech recognition failed: \(message)"
        case .insertionFailed(let message):
            "Could not insert text: \(message)"
        case .notReady(let message):
            message
        }
    }
}

struct DictationSnapshot: Equatable, Sendable {
    var phase: DictationPhase
    var stableTranscript: String
    var volatileTranscript: String
    var statusMessage: String

    var displayTranscript: String {
        let combined = stableTranscript + volatileTranscript
        return combined.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let initial = DictationSnapshot(
        phase: .idle,
        stableTranscript: "",
        volatileTranscript: "",
        statusMessage: "Hold Control+Option+Space to dictate"
    )
}

struct InsertionEvent: Equatable, Sendable {
    let id: UUID
    let message: String
    let succeeded: Bool
}

enum TranscriptAssembler {
    static func appendFinal(_ stable: String, finalText: String) -> String {
        let addition = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !addition.isEmpty else { return stable }
        if stable.isEmpty { return addition }
        return stable + " " + addition
    }

    static func attributedStringText(_ text: AttributedString) -> String {
        String(text.characters)
    }
}
