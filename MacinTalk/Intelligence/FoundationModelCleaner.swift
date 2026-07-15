import Foundation
import FoundationModels

struct TranscriptCleanupPrompt {
    static let instructions = """
    You are a writing assistant. Rewrite raw speech-to-text transcripts into clean written text.
    Remove filler words (um, uh, like, you know), false starts, and repeated phrases.
    Fix grammar and punctuation while preserving the speaker's meaning and voice.
    Return only the cleaned text with no commentary.
    """

    static func userPrompt(for transcript: String) -> String {
        "Clean this transcript:\n\n\(transcript)"
    }
}

enum TranscriptCleanerError: Error {
    case unavailable
    case emptyOutput
    case refusal
}

final class FoundationModelCleaner: TranscriptCleaning, @unchecked Sendable {
    private let model: SystemLanguageModel
    private let lock = NSLock()
    private var warmedSession: LanguageModelSession?

    init(model: SystemLanguageModel = SystemLanguageModel(guardrails: .permissiveContentTransformations)) {
        self.model = model
    }

    var isAvailable: Bool {
        switch model.availability {
        case .available:
            return true
        default:
            return false
        }
    }

    func prewarm() async {
        guard isAvailable else { return }
        let session = LanguageModelSession(
            model: model,
            instructions: Instructions(TranscriptCleanupPrompt.instructions)
        )
        session.prewarm(promptPrefix: Prompt(TranscriptCleanupPrompt.instructions))
        lock.withLock {
            warmedSession = session
        }
    }

    func clean(_ transcript: String) async -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return transcript }
        guard isAvailable else { return transcript }

        let bounded = String(trimmed.prefix(12_000))

        do {
            let session = lock.withLock { () -> LanguageModelSession in
                if let warmedSession {
                    self.warmedSession = nil
                    return warmedSession
                }
                return LanguageModelSession(
                    model: model,
                    instructions: Instructions(TranscriptCleanupPrompt.instructions)
                )
            }

            let options = GenerationOptions(temperature: 0.2)
            let response = try await session.respond(
                to: Prompt(TranscriptCleanupPrompt.userPrompt(for: bounded)),
                options: options
            )

            let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty || looksLikeRefusal(cleaned) {
                return transcript
            }
            return cleaned
        } catch LanguageModelSession.GenerationError.refusal {
            return transcript
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            return transcript
        } catch {
            return transcript
        }
    }

    private func looksLikeRefusal(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.hasPrefix("sorry") && lower.contains("can't")
    }
}

enum AppleIntelligenceReadiness {
    static var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        default:
            return false
        }
    }
}
