import Foundation
import Testing
@testable import MacinTalk

@MainActor
struct DictationCoordinatorTests {
    @Test func hotkeyPressStartsRecordingWhenReady() async {
        let speech = MockSpeechService()
        let cleaner = MockCleaner()
        let inserter = MockInserter()
        let hotkey = MockHotkeyMonitor()
        let permissions = MockPermissions()

        let coordinator = DictationCoordinator(
            speechService: speech,
            cleaner: cleaner,
            inserter: inserter,
            hotkeyMonitor: hotkey,
            permissions: permissions
        )

        await coordinator.start()
        hotkey.onHotkeyPressed?()

        try? await Task.sleep(for: .milliseconds(200))

        #expect(speech.startCount == 1)
        #expect(coordinator.snapshot.phase == .recording)
        #expect(cleaner.prewarmCount == 1)
    }

    @Test func hotkeyReleaseCleansAndInserts() async {
        let speech = MockSpeechService()
        speech.stopResult = "um hello there"
        let cleaner = MockCleaner()
        cleaner.cleanedText = "Hello there."
        let inserter = MockInserter()
        let hotkey = MockHotkeyMonitor()
        let permissions = MockPermissions()

        let coordinator = DictationCoordinator(
            speechService: speech,
            cleaner: cleaner,
            inserter: inserter,
            hotkeyMonitor: hotkey,
            permissions: permissions
        )

        await coordinator.start()
        hotkey.onHotkeyPressed?()
        try? await Task.sleep(for: .milliseconds(100))
        hotkey.onHotkeyReleased?()
        try? await Task.sleep(for: .milliseconds(300))

        #expect(speech.stopCount == 1)
        #expect(cleaner.cleanCount == 1)
        #expect(inserter.insertedText == "Hello there.")
        #expect(coordinator.snapshot.phase == .idle)
    }

    @Test func emptyTranscriptFailsGracefully() async {
        let speech = MockSpeechService()
        speech.stopResult = "   "
        let cleaner = MockCleaner()
        let inserter = MockInserter()
        let hotkey = MockHotkeyMonitor()
        let permissions = MockPermissions()

        let coordinator = DictationCoordinator(
            speechService: speech,
            cleaner: cleaner,
            inserter: inserter,
            hotkeyMonitor: hotkey,
            permissions: permissions
        )

        await coordinator.start()
        hotkey.onHotkeyPressed?()
        try? await Task.sleep(for: .milliseconds(100))
        hotkey.onHotkeyReleased?()
        try? await Task.sleep(for: .milliseconds(300))

        #expect(inserter.insertedText == nil)
        #expect(coordinator.snapshot.phase == .failed(.emptyTranscript))
    }

    @Test func notReadyBlocksRecording() async {
        let speech = MockSpeechService()
        let cleaner = MockCleaner()
        let inserter = MockInserter()
        let hotkey = MockHotkeyMonitor()
        let permissions = MockPermissions()
        permissions.readiness.microphoneGranted = false

        let coordinator = DictationCoordinator(
            speechService: speech,
            cleaner: cleaner,
            inserter: inserter,
            hotkeyMonitor: hotkey,
            permissions: permissions
        )

        await coordinator.start()
        hotkey.onHotkeyPressed?()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(speech.startCount == 0)
        if case .failed(.notReady) = coordinator.snapshot.phase {
            #expect(Bool(true))
        } else {
            Issue.record("Expected notReady failure")
        }
    }
}
