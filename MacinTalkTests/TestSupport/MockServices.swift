import AppKit
import Foundation
@testable import MacinTalk

final class MockSpeechService: SpeechTranscribing, @unchecked Sendable {
    var stableText = ""
    var volatileText = ""
    var prepareError: Error?
    var startError: Error?
    var stopResult = "hello world"
    var stopError: Error?
    var startDelayMilliseconds: UInt64 = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func prepare() async throws {
        if let prepareError { throw prepareError }
    }

    func startRecording() async throws {
        startCount += 1
        if startDelayMilliseconds > 0 {
            try await Task.sleep(for: .milliseconds(startDelayMilliseconds))
        }
        if let startError { throw startError }
        stableText = ""
        volatileText = "hel"
    }

    func stopRecording() async throws -> String {
        stopCount += 1
        if let stopError { throw stopError }
        return stopResult
    }
}

final class MockCleaner: TranscriptCleaning, @unchecked Sendable {
    var isAvailable = true
    var cleanedText = "Hello world."
    private(set) var prewarmCount = 0
    private(set) var cleanCount = 0
    private(set) var lastPrewarmStyle: WritingStyle?
    private(set) var lastCleanStyle: WritingStyle?

    func prewarm(style: WritingStyle) async {
        prewarmCount += 1
        lastPrewarmStyle = style
    }

    func clean(_ transcript: String, style: WritingStyle) async -> String {
        cleanCount += 1
        lastCleanStyle = style
        return cleanedText
    }
}

final class MockInserter: TextInserting, @unchecked Sendable {
    private(set) var insertedText: String?
    private(set) var clipboardText: String?
    var insertError: Error?
    var clipboardError: Error?

    func insert(_ text: String, activating application: NSRunningApplication?) throws {
        if let insertError { throw insertError }
        insertedText = text
    }

    func copyToClipboard(_ text: String) throws {
        if let clipboardError { throw clipboardError }
        clipboardText = text
    }
}

final class MockHotkeyMonitor: HotkeyMonitoring {
    var onHotkeyPressed: (() -> Void)?
    var onHotkeyReleased: (() -> Void)?
    private(set) var started = false
    private(set) var configuredShortcut = DictationShortcut.default

    func configure(shortcut: DictationShortcut) {
        configuredShortcut = shortcut
    }

    func start() throws {
        started = true
    }

    func stop() {
        started = false
    }
}

final class MockPermissions: PermissionChecking, @unchecked Sendable {
    var readiness = PermissionReadiness(
        microphoneGranted: true,
        inputMonitoringGranted: true,
        postEventGranted: true,
        speechLocaleSupported: true,
        speechAssetsInstalled: true,
        appleIntelligenceAvailable: true
    )

    func readinessSnapshot() async -> PermissionReadiness {
        readiness
    }

    func requestMicrophoneAccess() async -> Bool { true }
    func requestInputMonitoringAccess() -> Bool { true }
    func requestPostEventAccess() -> Bool { true }
}

@MainActor
final class MockHistoryStore: TranscriptionHistoryStoring {
    struct SavedRecord {
        let id: UUID
        let rawText: String
        let cleanedText: String
        let style: WritingStyle
        var insertionSucceeded: Bool?
        var insertionErrorMessage: String?
    }

    private(set) var records: [SavedRecord] = []
    var saveError: Error?
    var markInsertionError: Error?

    func save(rawText: String, cleanedText: String, style: WritingStyle) throws -> UUID {
        if let saveError { throw saveError }
        let record = SavedRecord(
            id: UUID(),
            rawText: rawText,
            cleanedText: cleanedText,
            style: style
        )
        records.append(record)
        return record.id
    }

    func markInsertionResult(id: UUID, succeeded: Bool, errorMessage: String?) throws {
        if let markInsertionError { throw markInsertionError }
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].insertionSucceeded = succeeded
        records[index].insertionErrorMessage = errorMessage
    }

    func delete(id: UUID) throws {
        records.removeAll { $0.id == id }
    }

    func deleteAll() throws {
        records.removeAll()
    }
}
