import Foundation
@testable import MacinTalk

final class MockSpeechService: SpeechTranscribing, @unchecked Sendable {
    var stableText = ""
    var volatileText = ""
    var prepareError: Error?
    var startError: Error?
    var stopResult = "hello world"
    var stopError: Error?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func prepare() async throws {
        if let prepareError { throw prepareError }
    }

    func startRecording() async throws {
        startCount += 1
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

    func prewarm() async {
        prewarmCount += 1
    }

    func clean(_ transcript: String) async -> String {
        cleanCount += 1
        cleanedText
    }
}

final class MockInserter: TextInserting, @unchecked Sendable {
    private(set) var insertedText: String?
    var insertError: Error?

    func insert(_ text: String) throws {
        if let insertError { throw insertError }
        insertedText = text
    }
}

final class MockHotkeyMonitor: HotkeyMonitoring {
    var onHotkeyPressed: (() -> Void)?
    var onHotkeyReleased: (() -> Void)?
    private(set) var started = false

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
