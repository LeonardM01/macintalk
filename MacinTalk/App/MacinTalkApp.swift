import SwiftUI

@main
struct MacinTalkApp: App {
    @Environment(\.openWindow) private var openWindow

    @State private var coordinator = DictationCoordinator(
        speechService: SpeechAnalyzerService(),
        cleaner: FoundationModelCleaner(),
        inserter: PasteboardTextInserter(),
        hotkeyMonitor: GlobalHotkeyMonitor(),
        permissions: PermissionManager()
    )

    @State private var readiness = PermissionReadiness(
        microphoneGranted: false,
        inputMonitoringGranted: false,
        postEventGranted: false,
        speechLocaleSupported: false,
        speechAssetsInstalled: false,
        appleIntelligenceAvailable: false
    )

    @State private var didLaunchSetup = false

    var body: some Scene {
        MenuBarExtra("MacinTalk", systemImage: menuBarIcon) {
            MenuBarContent(
                coordinator: coordinator,
                readiness: readiness,
                onRefresh: { Task { await refreshReadiness() } },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
            .task {
                await refreshReadinessOnLaunch()
            }
        }
        .menuBarExtraStyle(.window)

        Window("MacinTalk Setup", id: "setup") {
            SetupView(
                readiness: readiness,
                onRequestMicrophone: {
                    Task {
                        _ = await PermissionManager().requestMicrophoneAccess()
                        await refreshReadiness()
                    }
                },
                onRequestInputMonitoring: {
                    _ = PermissionManager().requestInputMonitoringAccess()
                    Task { await refreshReadiness() }
                },
                onRequestPostEvent: {
                    _ = PermissionManager().requestPostEventAccess()
                    Task { await refreshReadiness() }
                },
                onPrepareSpeechAssets: {
                    Task {
                        await coordinator.prepareIfNeeded()
                        await refreshReadiness()
                    }
                },
                onRefresh: {
                    Task { await refreshReadiness() }
                }
            )
        }
    }

    private var menuBarIcon: String {
        switch coordinator.snapshot.phase {
        case .recording:
            "mic.fill"
        case .cleaning, .inserting:
            "ellipsis.circle"
        case .failed:
            "exclamationmark.triangle"
        case .idle:
            "mic"
        }
    }

    @MainActor
    private func refreshReadinessOnLaunch() async {
        await refreshReadiness()
        await coordinator.start()
        await coordinator.prepareIfNeeded()
        await refreshReadiness()

        if !readiness.isReadyForDictation, !didLaunchSetup {
            didLaunchSetup = true
            openWindow(id: "setup")
        }
    }

    @MainActor
    private func refreshReadiness() async {
        readiness = await coordinator.refreshReadiness()
    }
}
