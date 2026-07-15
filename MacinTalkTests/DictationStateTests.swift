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

struct InsertionTargetResolverTests {
    @Test func pastesExternallyOnlyForNonSelfTargets() {
        #expect(
            InsertionTargetResolver.shouldPasteExternally(
                targetBundleIdentifier: "com.apple.TextEdit",
                ownBundleIdentifier: "com.macintalk.app"
            )
        )
        #expect(
            !InsertionTargetResolver.shouldPasteExternally(
                targetBundleIdentifier: "com.macintalk.app",
                ownBundleIdentifier: "com.macintalk.app"
            )
        )
        #expect(
            !InsertionTargetResolver.shouldPasteExternally(
                targetBundleIdentifier: nil,
                ownBundleIdentifier: "com.macintalk.app"
            )
        )
    }
}

struct ClipboardRetentionPolicyTests {
    @Test func retainsInsertedTextAfterPaste() {
        #expect(ClipboardRetentionPolicy.retainsInsertedTextAfterPaste())
    }
}

struct MicrophoneConfigurationTests {
    @Test func defaultDeviceRequiresInitialConfiguration() {
        #expect(
            MicrophoneCapture.needsConfiguration(
                configuredKey: nil,
                selectedDeviceID: nil
            )
        )
        #expect(
            !MicrophoneCapture.needsConfiguration(
                configuredKey: MicrophoneCapture.configurationKey(for: nil),
                selectedDeviceID: nil
            )
        )
    }

    @Test func explicitDeviceChangeRequiresReconfiguration() {
        #expect(
            MicrophoneCapture.needsConfiguration(
                configuredKey: MicrophoneCapture.defaultDeviceConfigurationKey,
                selectedDeviceID: "usb-mic"
            )
        )
    }
}

struct SpeechAudioPipelineStateTests {
    @Test func recordsFirstConversionFailureOnly() {
        let state = SpeechAudioPipelineState()
        state.noteConversionFailure(AudioBufferConverterError.conversionFailed)
        state.noteConversionFailure(AudioBufferConverterError.failedToCreateConverter)

        let snapshot = state.snapshot()
        #expect(snapshot.receivedSample == false)
        #expect(snapshot.conversionFailure is AudioBufferConverterError)
    }

    @Test func resetClearsPipelineState() {
        let state = SpeechAudioPipelineState()
        state.noteSuccessfulSample()
        state.noteConversionFailure(AudioBufferConverterError.conversionFailed)
        state.reset()

        let snapshot = state.snapshot()
        #expect(snapshot.receivedSample == false)
        #expect(snapshot.conversionFailure == nil)
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
