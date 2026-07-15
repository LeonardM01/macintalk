import AppKit
import Foundation

protocol SpeechTranscribing: Sendable {
    @MainActor var stableText: String { get }
    @MainActor var volatileText: String { get }
    @MainActor func prepare() async throws
    @MainActor func startRecording() async throws
    @MainActor func stopRecording() async throws -> String
}

protocol TranscriptCleaning: Sendable {
    var isAvailable: Bool { get }
    func prewarm(style: WritingStyle) async
    func clean(_ transcript: String, style: WritingStyle) async -> String
}

protocol TextInserting: AnyObject {
    func insert(_ text: String, activating application: NSRunningApplication?) throws
    func copyToClipboard(_ text: String) throws
}

protocol HotkeyMonitoring: AnyObject {
    var onHotkeyPressed: (() -> Void)? { get set }
    var onHotkeyReleased: (() -> Void)? { get set }
    func configure(shortcut: DictationShortcut)
    func start() throws
    func stop()
}

protocol PermissionChecking: Sendable {
    func readinessSnapshot() async -> PermissionReadiness
    func requestMicrophoneAccess() async -> Bool
    func requestInputMonitoringAccess() -> Bool
    func requestPostEventAccess() -> Bool
}

struct PermissionReadiness: Equatable, Sendable {
    var microphoneGranted: Bool
    var inputMonitoringGranted: Bool
    var postEventGranted: Bool
    var speechLocaleSupported: Bool
    var speechAssetsInstalled: Bool
    var appleIntelligenceAvailable: Bool
    var speechLocaleLabel: String = "English (United States)"
    var speechLocaleUsesFallback: Bool = false
    var preferredLocaleLabel: String = Locale.current.identifier(.bcp47)

    var isReadyForDictation: Bool {
        microphoneGranted
            && inputMonitoringGranted
            && postEventGranted
            && speechLocaleSupported
            && speechAssetsInstalled
    }

    var blockingIssues: [String] {
        var issues: [String] = []
        if !microphoneGranted { issues.append("Grant microphone access") }
        if !inputMonitoringGranted { issues.append("Grant Input Monitoring access") }
        if !postEventGranted { issues.append("Grant Accessibility (Post Event) access") }
        if !speechLocaleSupported { issues.append("Speech recognition is not available on this Mac") }
        if !speechAssetsInstalled { issues.append("Download speech recognition assets") }
        return issues
    }
}

@MainActor
@Observable
final class DictationCoordinator {
    private(set) var snapshot = DictationSnapshot.initial
    private(set) var isPreparingSpeechAssets = false

    private let speechService: any SpeechTranscribing
    private let cleaner: any TranscriptCleaning
    private let inserter: any TextInserting
    private let hotkeyMonitor: any HotkeyMonitoring
    private let permissions: any PermissionChecking
    private let settings: AppSettings
    private var historyStore: (any TranscriptionHistoryStoring)?

    private var sessionTask: Task<Void, Never>?
    private var isStartingRecording = false
    private var stopRequestedWhileStarting = false
    private var insertionTargetApp: NSRunningApplication?

    init(
        speechService: any SpeechTranscribing,
        cleaner: any TranscriptCleaning,
        inserter: any TextInserting,
        hotkeyMonitor: any HotkeyMonitoring,
        permissions: any PermissionChecking,
        settings: AppSettings,
        historyStore: (any TranscriptionHistoryStoring)? = nil
    ) {
        self.speechService = speechService
        self.cleaner = cleaner
        self.inserter = inserter
        self.hotkeyMonitor = hotkeyMonitor
        self.permissions = permissions
        self.settings = settings
        self.historyStore = historyStore
    }

    func setHistoryStore(_ store: any TranscriptionHistoryStoring) {
        historyStore = store
    }

    func start() async {
        hotkeyMonitor.onHotkeyPressed = { [weak self] in
            Task { @MainActor in self?.handleHotkeyPressed() }
        }
        hotkeyMonitor.onHotkeyReleased = { [weak self] in
            Task { @MainActor in self?.handleHotkeyReleased() }
        }

        do {
            try restartHotkeyMonitor()
        } catch {
            snapshot.phase = .failed(.inputMonitoringDenied)
            snapshot.statusMessage = "Could not start global hotkey monitor"
        }
    }

    func restartHotkeyMonitor() throws {
        hotkeyMonitor.configure(shortcut: settings.dictationShortcut)
        hotkeyMonitor.stop()
        try hotkeyMonitor.start()
        snapshot.statusMessage = settings.dictationShortcut.promptMessage
    }

    func applyShortcutChange() {
        do {
            try restartHotkeyMonitor()
        } catch {
            snapshot.statusMessage = "Could not update shortcut: Input Monitoring may be required"
        }
    }

    func applyInputDeviceChange() {
        snapshot.statusMessage = "Microphone updated. Applies to the next dictation."
    }

    func stop() {
        hotkeyMonitor.stop()
        sessionTask?.cancel()
        sessionTask = nil
    }

    func refreshReadiness() async -> PermissionReadiness {
        await permissions.readinessSnapshot()
    }

    func prepareIfNeeded() async {
        isPreparingSpeechAssets = true
        defer { isPreparingSpeechAssets = false }

        do {
            try await speechService.prepare()
            if !isBusyPhase(snapshot.phase) {
                snapshot.phase = .idle
            }
            snapshot.statusMessage = settings.dictationShortcut.promptMessage
        } catch {
            if !isBusyPhase(snapshot.phase) {
                snapshot.phase = .idle
            }
            snapshot.statusMessage = error.localizedDescription
        }
    }

    func manualStart() {
        handleHotkeyPressed()
    }

    func manualStop() {
        handleHotkeyReleased()
    }

    private func handleHotkeyPressed() {
        switch snapshot.phase {
        case .recording, .cleaning, .inserting:
            return
        default:
            break
        }

        sessionTask?.cancel()
        sessionTask = Task { @MainActor in
            await beginRecording()
        }
    }

    private func handleHotkeyReleased() {
        guard snapshot.phase == .recording || isStartingRecording else { return }

        if isStartingRecording {
            stopRequestedWhileStarting = true
        }

        Task { @MainActor in
            await finishRecording()
        }
    }

    private func beginRecording() async {
        guard !isStartingRecording, snapshot.phase != .recording else { return }

        isStartingRecording = true
        defer { isStartingRecording = false }

        insertionTargetApp = NSWorkspace.shared.frontmostApplication
        stopRequestedWhileStarting = false

        let readiness = await permissions.readinessSnapshot()
        guard readiness.isReadyForDictation else {
            snapshot.phase = .failed(.notReady(readiness.blockingIssues.joined(separator: ", ")))
            snapshot.statusMessage = readiness.blockingIssues.first ?? "Not ready"
            return
        }

        snapshot.statusMessage = "Starting…"

        await cleaner.prewarm(style: settings.writingStyle)
        if stopRequestedWhileStarting {
            resetAfterCancelledStart()
            return
        }

        do {
            try await speechService.startRecording()
            if stopRequestedWhileStarting {
                try? await speechService.stopRecording()
                resetAfterCancelledStart()
                return
            }

            snapshot = DictationSnapshot(
                phase: .recording,
                stableTranscript: "",
                volatileTranscript: "",
                statusMessage: "Listening…"
            )
            updateTranscriptFromService()
            startTranscriptObservation()
        } catch {
            snapshot.phase = .failed(mapSpeechError(error))
            snapshot.statusMessage = error.localizedDescription
        }
    }

    private func finishRecording() async {
        if isStartingRecording {
            stopRequestedWhileStarting = true
            while isStartingRecording {
                try? await Task.sleep(for: .milliseconds(25))
            }
            guard snapshot.phase == .recording else { return }
        } else {
            guard snapshot.phase == .recording else { return }
        }

        snapshot.phase = .cleaning
        snapshot.statusMessage = "Cleaning transcript…"

        do {
            let rawTranscript = try await speechService.stopRecording()
            let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                resetAfterCancelledStart()
                return
            }

            snapshot.stableTranscript = trimmed
            snapshot.volatileTranscript = ""

            let cleaned = await cleaner.clean(trimmed, style: settings.writingStyle)
            let output = cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? trimmed : cleaned

            var historyID: UUID?
            var historyStatusMessage: String?
            if let historyStore {
                do {
                    historyID = try historyStore.save(
                        rawText: trimmed,
                        cleanedText: output,
                        style: settings.writingStyle
                    )
                } catch {
                    historyStatusMessage = "Could not save to history: \(error.localizedDescription)"
                }
            }

            snapshot.phase = .inserting
            snapshot.statusMessage = "Inserting text…"

            do {
                let insertionTarget = InsertionTargetResolver.externalTarget(from: insertionTargetApp)
                if let insertionTarget {
                    try inserter.insert(output, activating: insertionTarget)
                } else {
                    try inserter.copyToClipboard(output)
                }
                if let historyID, let historyStore {
                    do {
                        try historyStore.markInsertionResult(id: historyID, succeeded: true, errorMessage: nil)
                    } catch {
                        historyStatusMessage = "Text inserted, but history update failed: \(error.localizedDescription)"
                    }
                }
                snapshot = DictationSnapshot.initial
                if let historyStatusMessage {
                    snapshot.statusMessage = historyStatusMessage
                } else if insertionTarget == nil {
                    snapshot.statusMessage = "Copied to clipboard"
                } else {
                    snapshot.statusMessage = "Inserted text"
                }
            } catch {
                if let historyID, let historyStore {
                    do {
                        try historyStore.markInsertionResult(
                            id: historyID,
                            succeeded: false,
                            errorMessage: error.localizedDescription
                        )
                    } catch {
                        historyStatusMessage = "Insertion failed and history update failed: \(error.localizedDescription)"
                    }
                }
                snapshot.phase = .failed(mapFinishError(error))
                snapshot.statusMessage = historyStatusMessage ?? error.localizedDescription
            }
        } catch {
            snapshot.phase = .failed(mapFinishError(error))
            snapshot.statusMessage = error.localizedDescription
        }
    }

    private func resetAfterCancelledStart() {
        snapshot = DictationSnapshot.initial
        snapshot.statusMessage = settings.dictationShortcut.promptMessage
    }

    func updateTranscriptFromService() {
        guard snapshot.phase == .recording else { return }
        snapshot.stableTranscript = speechService.stableText
        snapshot.volatileTranscript = speechService.volatileText
    }

    private func startTranscriptObservation() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            while self.snapshot.phase == .recording {
                self.updateTranscriptFromService()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func mapSpeechError(_ error: Error) -> DictationFailure {
        if let failure = error as? DictationFailure { return failure }
        return .speechRecognitionFailed(error.localizedDescription)
    }

    private func mapFinishError(_ error: Error) -> DictationFailure {
        if let failure = error as? DictationFailure { return failure }
        if error is TextInsertionError {
            return .insertionFailed(error.localizedDescription)
        }
        return .speechRecognitionFailed(error.localizedDescription)
    }

    private func isBusyPhase(_ phase: DictationPhase) -> Bool {
        switch phase {
        case .recording, .cleaning, .inserting:
            true
        default:
            false
        }
    }
}

enum TextInsertionError: LocalizedError {
    case postEventAccessDenied
    case pasteFailed
    case clipboardCopyFailed

    var errorDescription: String? {
        switch self {
        case .postEventAccessDenied:
            "Accessibility permission is required to paste into other apps."
        case .pasteFailed:
            "Failed to simulate paste command."
        case .clipboardCopyFailed:
            "Failed to copy transcription to the clipboard."
        }
    }
}

enum InsertionTargetResolver {
    static func externalTarget(
        from application: NSRunningApplication?,
        ownBundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) -> NSRunningApplication? {
        guard let application else { return nil }
        guard application.bundleIdentifier != ownBundleIdentifier else { return nil }
        return application
    }

    static func shouldPasteExternally(
        targetBundleIdentifier: String?,
        ownBundleIdentifier: String?
    ) -> Bool {
        guard let targetBundleIdentifier else { return false }
        return targetBundleIdentifier != ownBundleIdentifier
    }
}
