import Foundation
import SwiftData

@MainActor
protocol TranscriptionHistoryStoring: AnyObject {
    func save(
        rawText: String,
        cleanedText: String,
        style: WritingStyle,
        durationSeconds: Double?
    ) throws -> UUID

    func markInsertionResult(
        id: UUID,
        succeeded: Bool,
        errorMessage: String?
    ) throws

    func delete(id: UUID) throws
    func deleteAll() throws
}

@MainActor
final class SwiftDataTranscriptionHistoryStore: TranscriptionHistoryStoring {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(
        rawText: String,
        cleanedText: String,
        style: WritingStyle,
        durationSeconds: Double?
    ) throws -> UUID {
        let record = TranscriptionRecord(
            rawText: rawText,
            cleanedText: cleanedText,
            writingStyle: style,
            durationSeconds: durationSeconds
        )
        modelContext.insert(record)
        try modelContext.save()
        return record.id
    }

    func markInsertionResult(
        id: UUID,
        succeeded: Bool,
        errorMessage: String?
    ) throws {
        guard let record = try fetchRecord(id: id) else { return }
        record.insertionSucceeded = succeeded
        record.insertionErrorMessage = errorMessage
        try modelContext.save()
    }

    func delete(id: UUID) throws {
        guard let record = try fetchRecord(id: id) else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    func deleteAll() throws {
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let records = try modelContext.fetch(descriptor)
        for record in records {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    private func fetchRecord(id: UUID) throws -> TranscriptionRecord? {
        var descriptor = FetchDescriptor<TranscriptionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

enum ModelContainerFactory {
    static func makePersistent() throws -> ModelContainer {
        try ModelContainer(for: TranscriptionRecord.self)
    }

    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: TranscriptionRecord.self, configurations: configuration)
    }
}
