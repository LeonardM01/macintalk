import Foundation
import Testing
@testable import MacinTalk

@MainActor
struct DictationCoordinatorTests {
  private func makeCoordinator(
    speech: MockSpeechService = MockSpeechService(),
    cleaner: MockCleaner = MockCleaner(),
    inserter: MockInserter = MockInserter(),
    hotkey: MockHotkeyMonitor = MockHotkeyMonitor(),
    permissions: MockPermissions = MockPermissions(),
    settings: AppSettings = AppSettings(),
    history: MockHistoryStore = MockHistoryStore()
  ) -> DictationCoordinator {
    DictationCoordinator(
      speechService: speech,
      cleaner: cleaner,
      inserter: inserter,
      hotkeyMonitor: hotkey,
      permissions: permissions,
      settings: settings,
      historyStore: history
    )
  }

  @Test func hotkeyPressStartsRecordingWhenReady() async {
    let speech = MockSpeechService()
    let cleaner = MockCleaner()
    let settings = AppSettings()
    settings.writingStyle = .business
    let coordinator = makeCoordinator(speech: speech, cleaner: cleaner, settings: settings)

    await coordinator.start()
    coordinator.manualStart()

    try? await Task.sleep(for: .milliseconds(200))

    #expect(speech.startCount == 1)
    #expect(coordinator.snapshot.phase == .recording)
    #expect(cleaner.prewarmCount == 1)
    #expect(cleaner.lastPrewarmStyle == .business)
  }

  @Test func hotkeyReleaseCleansInsertsAndSavesHistory() async {
    let speech = MockSpeechService()
    speech.stopResult = "um hello there"
    let cleaner = MockCleaner()
    cleaner.cleanedText = "Hello there."
    let inserter = MockInserter()
    let history = MockHistoryStore()
    let settings = AppSettings()
    settings.writingStyle = .casual
    let coordinator = makeCoordinator(
      speech: speech,
      cleaner: cleaner,
      inserter: inserter,
      settings: settings,
      history: history
    )

    await coordinator.start()
    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(100))
    coordinator.manualStop()
    try? await Task.sleep(for: .milliseconds(300))

    #expect(speech.stopCount == 1)
    #expect(cleaner.cleanCount == 1)
    #expect(cleaner.lastCleanStyle == .casual)
    #expect(inserter.clipboardText == "Hello there.")
    #expect(inserter.insertedText == nil)
    #expect(history.records.count == 1)
    #expect(history.records.first?.rawText == "um hello there")
    #expect(history.records.first?.cleanedText == "Hello there.")
    #expect(history.records.first?.insertionSucceeded == true)
    #expect(coordinator.snapshot.phase == .idle)
    #expect(coordinator.snapshot.statusMessage == "Copied to clipboard")
  }

  @Test func emptyTranscriptFailsGracefully() async {
    let speech = MockSpeechService()
    speech.stopResult = "   "
    let inserter = MockInserter()
    let history = MockHistoryStore()
    let coordinator = makeCoordinator(speech: speech, inserter: inserter, history: history)

    await coordinator.start()
    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(100))
    coordinator.manualStop()
    try? await Task.sleep(for: .milliseconds(300))

    #expect(inserter.insertedText == nil)
    #expect(history.records.isEmpty)
    #expect(coordinator.snapshot.phase == .idle)
  }

  @Test func insertionFailureIsRecordedInHistory() async {
    let speech = MockSpeechService()
    speech.stopResult = "hello"
    let cleaner = MockCleaner()
    cleaner.cleanedText = "Hello."
    let inserter = MockInserter()
    inserter.clipboardError = TextInsertionError.clipboardCopyFailed
    let history = MockHistoryStore()
    let coordinator = makeCoordinator(
      speech: speech,
      cleaner: cleaner,
      inserter: inserter,
      history: history
    )

    await coordinator.start()
    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(100))
    coordinator.manualStop()
    try? await Task.sleep(for: .milliseconds(300))

    #expect(history.records.count == 1)
    #expect(history.records.first?.insertionSucceeded == false)
    #expect(history.records.first?.insertionErrorMessage != nil)
    if case .failed(.insertionFailed) = coordinator.snapshot.phase {
      #expect(Bool(true))
    } else {
      Issue.record("Expected insertion failure")
    }
  }

  @Test func notReadyBlocksRecording() async {
    let speech = MockSpeechService()
    let permissions = MockPermissions()
    permissions.readiness.microphoneGranted = false
    let coordinator = makeCoordinator(speech: speech, permissions: permissions)

    await coordinator.start()
    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(100))

    #expect(speech.startCount == 0)
    if case .failed(.notReady) = coordinator.snapshot.phase {
      #expect(Bool(true))
    } else {
      Issue.record("Expected notReady failure")
    }
  }

  @Test func consecutiveDictationsSaveMultipleHistoryRecords() async {
    let speech = MockSpeechService()
    speech.stopResult = "first phrase"
    let cleaner = MockCleaner()
    cleaner.cleanedText = "First phrase."
    let inserter = MockInserter()
    let history = MockHistoryStore()
    let coordinator = makeCoordinator(
      speech: speech,
      cleaner: cleaner,
      inserter: inserter,
      history: history
    )

    await coordinator.start()

    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(100))
    coordinator.manualStop()
    try? await Task.sleep(for: .milliseconds(300))

    speech.stopResult = "second phrase"
    cleaner.cleanedText = "Second phrase."

    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(100))
    coordinator.manualStop()
    try? await Task.sleep(for: .milliseconds(300))

    #expect(speech.startCount == 2)
    #expect(speech.stopCount == 2)
    #expect(history.records.count == 2)
    #expect(history.records[0].cleanedText == "First phrase.")
    #expect(history.records[1].cleanedText == "Second phrase.")
    #expect(coordinator.snapshot.phase == .idle)
  }

  @Test func historySaveFailureStillInsertsAndReportsStatus() async {
    let speech = MockSpeechService()
    speech.stopResult = "hello there"
    let cleaner = MockCleaner()
    cleaner.cleanedText = "Hello there."
    let inserter = MockInserter()
    let history = MockHistoryStore()
    history.saveError = NSError(domain: "test", code: 1)
    let coordinator = makeCoordinator(
      speech: speech,
      cleaner: cleaner,
      inserter: inserter,
      history: history
    )

    await coordinator.start()
    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(100))
    coordinator.manualStop()
    try? await Task.sleep(for: .milliseconds(300))

    #expect(inserter.clipboardText == "Hello there.")
    #expect(inserter.insertedText == nil)
    #expect(history.records.isEmpty)
    #expect(coordinator.snapshot.phase == .idle)
    #expect(coordinator.snapshot.statusMessage.contains("Could not save to history"))
  }

  @Test func durationExcludesCleaningTime() async throws {
    let speech = MockSpeechService()
    speech.stopResult = "hello there"
    let cleaner = MockCleaner()
    cleaner.cleanedText = "Hello there."
    cleaner.cleanDelayMilliseconds = 200
    let inserter = MockInserter()
    let history = MockHistoryStore()
    let coordinator = makeCoordinator(
      speech: speech,
      cleaner: cleaner,
      inserter: inserter,
      history: history
    )

    await coordinator.start()
    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(100))
    coordinator.manualStop()
    try? await Task.sleep(for: .milliseconds(500))

    #expect(history.records.count == 1)
    let duration = try #require(history.records.first?.durationSeconds)
    #expect(duration < 0.15)
  }

  @Test func cancelWhileRecordingDiscardsTranscript() async {
    let speech = MockSpeechService()
    let cleaner = MockCleaner()
    let inserter = MockInserter()
    let history = MockHistoryStore()
    let coordinator = makeCoordinator(speech: speech, cleaner: cleaner, inserter: inserter, history: history)

    await coordinator.start()
    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(100))
    #expect(coordinator.snapshot.phase == .recording)

    coordinator.cancelRecording()
    try? await Task.sleep(for: .milliseconds(200))

    #expect(history.records.isEmpty)
    #expect(cleaner.cleanCount == 0)
    #expect(inserter.insertedText == nil)
    #expect(coordinator.snapshot.phase == .idle)
  }

  @Test func cancelWhileStartingDoesNotLeakSession() async {
    let speech = MockSpeechService()
    speech.startDelayMilliseconds = 200
    let cleaner = MockCleaner()
    let inserter = MockInserter()
    let history = MockHistoryStore()
    let coordinator = makeCoordinator(speech: speech, cleaner: cleaner, inserter: inserter, history: history)

    await coordinator.start()
    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(20))
    coordinator.cancelRecording()
    try? await Task.sleep(for: .milliseconds(400))

    #expect(history.records.isEmpty)
    #expect(cleaner.cleanCount == 0)
    #expect(inserter.insertedText == nil)
    #expect(coordinator.snapshot.phase == .idle)
  }

  @Test func lastInsertionEventRecordsSuccess() async {
    let speech = MockSpeechService()
    speech.stopResult = "hello there"
    let cleaner = MockCleaner()
    cleaner.cleanedText = "Hello there."
    let inserter = MockInserter()
    let history = MockHistoryStore()
    let coordinator = makeCoordinator(
      speech: speech,
      cleaner: cleaner,
      inserter: inserter,
      history: history
    )

    await coordinator.start()
    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(100))
    coordinator.manualStop()
    try? await Task.sleep(for: .milliseconds(300))

    #expect(coordinator.lastInsertionEvent?.succeeded == true)
  }

  @Test func lastInsertionEventRecordsFailure() async {
    let speech = MockSpeechService()
    speech.stopResult = "hello"
    let cleaner = MockCleaner()
    cleaner.cleanedText = "Hello."
    let inserter = MockInserter()
    inserter.clipboardError = TextInsertionError.clipboardCopyFailed
    let history = MockHistoryStore()
    let coordinator = makeCoordinator(
      speech: speech,
      cleaner: cleaner,
      inserter: inserter,
      history: history
    )

    await coordinator.start()
    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(100))
    coordinator.manualStop()
    try? await Task.sleep(for: .milliseconds(300))

    #expect(coordinator.lastInsertionEvent?.succeeded == false)
  }

  @Test func quickReleaseDuringStartupDoesNotEnterFailureState() async {
    let speech = MockSpeechService()
    speech.startDelayMilliseconds = 200
    let coordinator = makeCoordinator(speech: speech)

    await coordinator.start()
    coordinator.manualStart()
    try? await Task.sleep(for: .milliseconds(20))
    coordinator.manualStop()
    try? await Task.sleep(for: .milliseconds(400))

    #expect(speech.startCount == 1)
    #expect(coordinator.snapshot.phase == .idle)
  }
}
