import Foundation
import SwiftData

@Model
final class TranscriptionRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var rawText: String
    var cleanedText: String
    var writingStyleRaw: String
    var insertionSucceeded: Bool?
    var insertionErrorMessage: String?
    var durationSeconds: Double?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        rawText: String,
        cleanedText: String,
        writingStyle: WritingStyle,
        durationSeconds: Double? = nil,
        insertionSucceeded: Bool? = nil,
        insertionErrorMessage: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.rawText = rawText
        self.cleanedText = cleanedText
        self.writingStyleRaw = writingStyle.rawValue
        self.durationSeconds = durationSeconds
        self.insertionSucceeded = insertionSucceeded
        self.insertionErrorMessage = insertionErrorMessage
    }

    var writingStyle: WritingStyle {
        WritingStyle(rawValue: writingStyleRaw) ?? .balanced
    }

    var previewText: String {
        let text = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return rawText }
        return text
    }

    var wordCount: Int {
        WordCounter.count(cleanedText)
    }
}
