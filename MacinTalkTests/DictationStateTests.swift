import Foundation
import Testing
@testable import MacinTalk

struct TranscriptAssemblyTests {
    @Test func appendFinalAddsSpacing() {
        let result = TranscriptAssembler.appendFinal("Hello", finalText: "world")
        #expect(result == "Hello world")
    }

    @Test func appendFinalIgnoresEmptyAddition() {
        let result = TranscriptAssembler.appendFinal("Hello", finalText: "   ")
        #expect(result == "Hello")
    }

    @Test func appendFinalStartsFromEmpty() {
        let result = TranscriptAssembler.appendFinal("", finalText: "world")
        #expect(result == "world")
    }
}

struct HotkeyEdgeHandlerTests {
    @Test func shouldStartOnlyWhenIdleAndNotRepeat() {
        #expect(HotkeyEdgeHandler.shouldStart(isIdle: true, isRepeat: false, alreadyHeld: false))
        #expect(!HotkeyEdgeHandler.shouldStart(isIdle: false, isRepeat: false, alreadyHeld: false))
        #expect(!HotkeyEdgeHandler.shouldStart(isIdle: true, isRepeat: true, alreadyHeld: false))
        #expect(!HotkeyEdgeHandler.shouldStart(isIdle: true, isRepeat: false, alreadyHeld: true))
    }

    @Test func shouldStopOnlyWhenRecordingAndHeld() {
        #expect(HotkeyEdgeHandler.shouldStop(isRecording: true, isHeld: true))
        #expect(!HotkeyEdgeHandler.shouldStop(isRecording: false, isHeld: true))
        #expect(!HotkeyEdgeHandler.shouldStop(isRecording: true, isHeld: false))
    }
}

struct PasteboardRestorePolicyTests {
    @Test func shouldRestoreWhenInsertedTextStillPresent() {
        let snapshot = PasteboardSnapshot(changeCount: 1, items: [])
        #expect(
            PasteboardRestorePolicy.shouldRestore(
                snapshot: snapshot,
                currentChangeCount: 2,
                insertedText: "hello",
                currentText: "hello"
            )
        )
    }

    @Test func shouldNotRestoreWhenClipboardChanged() {
        let snapshot = PasteboardSnapshot(changeCount: 1, items: [])
        #expect(
            !PasteboardRestorePolicy.shouldRestore(
                snapshot: snapshot,
                currentChangeCount: 2,
                insertedText: "hello",
                currentText: "different"
            )
        )
    }
}

struct PermissionReadinessTests {
    @Test func readinessRequiresCorePermissions() {
        let ready = PermissionReadiness(
            microphoneGranted: true,
            inputMonitoringGranted: true,
            postEventGranted: true,
            speechLocaleSupported: true,
            speechAssetsInstalled: true,
            appleIntelligenceAvailable: false
        )
        #expect(ready.isReadyForDictation)
        #expect(ready.blockingIssues.isEmpty)
    }

    @Test func readinessReportsBlockingIssues() {
        let notReady = PermissionReadiness(
            microphoneGranted: false,
            inputMonitoringGranted: false,
            postEventGranted: true,
            speechLocaleSupported: true,
            speechAssetsInstalled: false,
            appleIntelligenceAvailable: true
        )
        #expect(!notReady.isReadyForDictation)
        #expect(notReady.blockingIssues.count == 3)
    }
}
