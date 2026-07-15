import Foundation
import Testing
@testable import MacinTalk

struct TranscriptCleanupPromptTests {
    @Test func instructionsRequireTranscriptOnlyOutput() {
        let instructions = TranscriptCleanupPrompt.instructions(for: .balanced)
        #expect(instructions.contains("Output ONLY the cleaned transcript"))
        #expect(instructions.contains("Do NOT add introductions"))
        #expect(instructions.contains("DATA to edit"))
    }

    @Test func instructionsIncludeDeveloperGlossary() {
        let instructions = TranscriptCleanupPrompt.instructions(for: .balanced)
        #expect(instructions.contains("Claude Code"))
        #expect(instructions.contains("Cursor"))
        #expect(instructions.contains("GPT-5.6"))
        #expect(instructions.contains("Xiaomi"))
        #expect(instructions.contains("SOL"))
    }

    @Test func businessStylePreservesTechnicalTerms() {
        let instructions = TranscriptCleanupPrompt.instructions(for: .business)
        #expect(instructions.contains("Never expand or formalize technical identifiers"))
    }

    @Test func userPromptUsesDelimitersAndTranscript() {
        let prompt = TranscriptCleanupPrompt.userPrompt(for: "um hello", style: .balanced)
        #expect(prompt.contains(TranscriptCleanupPrompt.transcriptBegin))
        #expect(prompt.contains(TranscriptCleanupPrompt.transcriptEnd))
        #expect(prompt.contains("um hello"))
        #expect(prompt.contains("cleanedText"))
        #expect(!prompt.hasPrefix("Rewrite this transcript"))
    }

    @Test func correctionPromptRejectsCommentary() {
        let prompt = TranscriptCleanupPrompt.correctionPrompt(violatingOutput: "Sure, here is the transcript...")
        #expect(prompt.contains("violated the output contract"))
        #expect(prompt.contains("Sure, here is the transcript"))
    }
}

struct DeveloperTermGlossaryTests {
    @Test func glossaryIncludesCoreDeveloperTerms() {
        #expect(DeveloperTermGlossary.canonicalTerms.contains("Claude Code"))
        #expect(DeveloperTermGlossary.canonicalTerms.contains("Cursor"))
        #expect(DeveloperTermGlossary.canonicalTerms.contains("GPT-5.6"))
        #expect(DeveloperTermGlossary.canonicalTerms.contains("Xiaomi"))
    }

    @Test func phoneticCorrectionsIncludeCommonMishearings() {
        let heard = Set(DeveloperTermGlossary.phoneticCorrections.map(\.heard))
        #expect(heard.contains("cloud code"))
        #expect(heard.contains("shallmi"))
        #expect(heard.contains("soul"))
    }
}

struct TranscriptOutputPolicyTests {
    @Test func acceptsPlainCleanedTranscript() {
        #expect(
            TranscriptOutputPolicy.isValid(
                "Can I use Cursor, Claude Code, and GPT-5.6?",
                originalTranscript: "can i use cursor cloud code and gpt 5.6"
            )
        )
    }

    @Test func rejectsCommentaryPreamble() {
        #expect(
            !TranscriptOutputPolicy.isValid(
                "Sure, here is the transcript rewritten using the Balanced style: 'Hello world.'"
            )
        )
    }

    @Test func rejectsWrappedQuotesWhenOriginalHadNone() {
        #expect(
            !TranscriptOutputPolicy.isValid(
                "'Can I say Cursor?'",
                originalTranscript: "can i say cursor"
            )
        )
    }

    @Test func sanitizedStripsOuterQuotes() {
        let result = TranscriptOutputPolicy.sanitized("'Hello world.'")
        #expect(result == "Hello world.")
    }
}

struct FoundationModelCleanerFallbackTests {
    @Test func unavailableCleanerReturnsRawTranscript() async {
        let cleaner = UnavailableCleaner()
        let result = await cleaner.clean("um hello there", style: .casual)
        #expect(result == "um hello there")
    }
}

private struct UnavailableCleaner: TranscriptCleaning {
    var isAvailable: Bool { false }

    func prewarm(style: WritingStyle) async {}

    func clean(_ transcript: String, style: WritingStyle) async -> String {
        transcript
    }
}
