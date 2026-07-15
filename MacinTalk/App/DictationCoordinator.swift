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
    func prewarm() async
    func clean(_ transcript: String) async -> String
}

protocol TextInserting: Sendable {
    func insert(_ text: String) throws
}

protocol HotkeyMonitoring: AnyObject {
    var onHotkeyPressed: (() -> Void)? { get set }
    var onHotkeyReleased: (() -> Void)? { get set }
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
        if !speechLocaleSupported { issues.append("Current locale is not supported for speech recognition") }
        if !speechAssetsInstalled { issues.append("Speech recognition assets need to be downloaded") }
        return issues
    }
}

@MainActor
@Observable
final class DictationCoordinator {
    private(set) var snapshot = DictationSnapshot.initial

    private let speechService: any SpeechTranscribing
    private let cleaner: any TranscriptCleaning
    private let inserter: any TextInserting
    private let hotkeyMonitor: any HotkeyMonitoring
    private let permissions: any PermissionChecking

    private var sessionTask: Task<Void, Never>?

    init(
        speechService: any SpeechTranscribing,
        cleaner: any TranscriptCleaning,
        inserter: any TextInserting,
        hotkeyMonitor: any HotkeyMonitoring,
        permissions: any PermissionChecking
    ) {
        self.speechService = speechService
        self.cleaner = cleaner
        self.inserter = inserter
        self.hotkeyMonitor = hotkeyMonitor
        self.permissions = permissions
    }

    func start() async {
        hotkeyMonitor.onHotkeyPressed = { [weak self] in
            Task { @MainActor in self?.handleHotkeyPressed() }
        }
        hotkeyMonitor.onHotkeyReleased = { [weak self] in
            Task { @MainActor in self?.handleHotkeyReleased() }
        }

        do {
            try hotkeyMonitor.start()
            snapshot.statusMessage = "Hold Control+Option+Space to dictate"
        } catch {
            snapshot.phase = .failed(.inputMonitoringDenied)
            snapshot.statusMessage = "Could not start global hotkey monitor"
        }
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
        do {
            try await speechService.prepare()
            snapshot.statusMessage = "Ready"
        } catch {
            snapshot.phase = .failed(mapSpeechError(error))
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
        guard snapshot.phase == .idle || snapshot.phase == .failed(.emptyTranscript) else { return }

        sessionTask?.cancel()
        sessionTask = Task { @MainActor in
            await beginRecording()
        }
    }

    private func handleHotkeyReleased() {
        guard snapshot.phase == .recording else { return }

        sessionTask?.cancel()
        sessionTask = Task { @MainActor in
            await finishRecording()
        }
    }

    private func beginRecording() async {
        let readiness = await permissions.readinessSnapshot()
        guard readiness.isReadyForDictation else {
            snapshot.phase = .failed(.notReady(readiness.blockingIssues.joined(separator: ", ")))
            snapshot.statusMessage = readiness.blockingIssues.first ?? "Not ready"
            return
        }

        snapshot = DictationSnapshot(
            phase: .recording,
            stableTranscript: "",
            volatileTranscript: "",
            statusMessage: "Listening…"
        )

        await cleaner.prewarm()

        do {
            try await speechService.startRecording()
            updateTranscriptFromService()
            startTranscriptObservation()
        } catch {
            snapshot.phase = .failed(mapSpeechError(error))
            snapshot.statusMessage = error.localizedDescription
        }
    }

    private func finishRecording() async {
        snapshot.phase = .cleaning
        snapshot.statusMessage = "Cleaning transcript…"

        do {
            let rawTranscript = try await speechService.stopRecording()
            let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                snapshot = DictationSnapshot.initial
                snapshot.phase = .failed(.emptyTranscript)
                snapshot.statusMessage = "No speech detected"
                return
            }

            snapshot.stableTranscript = trimmed
            snapshot.volatileTranscript = ""

            let cleaned = await cleaner.clean(trimmed)
            let output = cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? trimmed : cleaned

            snapshot.phase = .inserting
            snapshot.statusMessage = "Inserting text…"

            try inserter.insert(output)

            snapshot = DictationSnapshot.initial
            snapshot.statusMessage = "Inserted text"
        } catch {
            snapshot.phase = .failed(mapFinishError(error))
            snapshot.statusMessage = error.localizedDescription
        }
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
}

enum TextInsertionError: LocalizedError {
    case postEventAccessDenied
    case pasteFailed

    var errorDescription: String? {
        switch self {
        case .postEventAccessDenied:
            "Accessibility permission is required to paste into other apps."
        case .pasteFailed:
            "Failed to simulate paste command."
        }
    }
}
