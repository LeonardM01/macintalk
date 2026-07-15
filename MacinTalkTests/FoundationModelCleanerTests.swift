import Foundation
import Testing
@testable import MacinTalk

struct TranscriptCleanupPromptTests {
    @Test func userPromptIncludesTranscript() {
        let prompt = TranscriptCleanupPrompt.userPrompt(for: "um hello")
        #expect(prompt.contains("um hello"))
        #expect(prompt.contains("Clean this transcript"))
    }
}

struct FoundationModelCleanerFallbackTests {
    @Test func unavailableCleanerReturnsRawTranscript() async {
        let cleaner = UnavailableCleaner()
        let result = await cleaner.clean("um hello there")
        #expect(result == "um hello there")
    }
}

private struct UnavailableCleaner: TranscriptCleaning {
    var isAvailable: Bool { false }

    func prewarm() async {}

    func clean(_ transcript: String) async -> String {
        transcript
    }
}
