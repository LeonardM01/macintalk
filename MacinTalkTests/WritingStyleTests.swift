import Foundation
import SwiftData
import Testing
@testable import MacinTalk

struct WritingStyleTests {
    @Test func allStylesHaveTitles() {
        for style in WritingStyle.allCases {
            #expect(!style.title.isEmpty)
            #expect(!style.subtitle.isEmpty)
        }
    }

    @Test func promptInstructionsVaryByStyle() {
        let casual = TranscriptCleanupPrompt.instructions(for: .casual)
        let business = TranscriptCleanupPrompt.instructions(for: .business)

        #expect(casual.localizedCaseInsensitiveContains("casual"))
        #expect(business.localizedCaseInsensitiveContains("formal"))
        #expect(casual != business)
    }

    @Test func userPromptIncludesStyleAndTranscript() {
        let prompt = TranscriptCleanupPrompt.userPrompt(for: "um hello", style: .balanced)
        #expect(prompt.contains("Balanced"))
        #expect(prompt.contains("um hello"))
    }
}

@MainActor
struct TranscriptionHistoryStoreTests {
    @Test func saveFetchDeleteAndClear() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = ModelContext(container)
        let store = SwiftDataTranscriptionHistoryStore(modelContext: context)

        let id = try store.save(
            rawText: "um hi",
            cleanedText: "Hi.",
            style: .casual,
            durationSeconds: 4.5
        )

        let descriptor = FetchDescriptor<TranscriptionRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let records = try context.fetch(descriptor)
        #expect(records.count == 1)
        #expect(records.first?.id == id)
        #expect(records.first?.rawText == "um hi")
        #expect(records.first?.durationSeconds == 4.5)

        try store.markInsertionResult(id: id, succeeded: true, errorMessage: nil)
        let updated = try context.fetch(descriptor).first
        #expect(updated?.insertionSucceeded == true)

        try store.delete(id: id)
        #expect(try context.fetch(descriptor).isEmpty)

        _ = try store.save(rawText: "a", cleanedText: "A", style: .business, durationSeconds: nil)
        _ = try store.save(rawText: "b", cleanedText: "B", style: .balanced, durationSeconds: nil)
        try store.deleteAll()
        #expect(try context.fetch(descriptor).isEmpty)
    }
}
