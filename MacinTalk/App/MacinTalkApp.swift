import AppKit
import SwiftData
import SwiftUI

@main
struct MacinTalkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let modelContainer: ModelContainer

    @State private var settings = AppSettings()
    @State private var coordinator: DictationCoordinator
    @State private var readiness = PermissionReadiness(
        microphoneGranted: false,
        inputMonitoringGranted: false,
        postEventGranted: false,
        speechLocaleSupported: false,
        speechAssetsInstalled: false,
        appleIntelligenceAvailable: false
    )

    @State private var didLaunchSetup = false

    init() {
        let container = (try? ModelContainerFactory.makePersistent())
            ?? (try! ModelContainerFactory.makeInMemory())
        modelContainer = container

        let appSettings = AppSettings()
        let historyStore = SwiftDataTranscriptionHistoryStore(modelContext: container.mainContext)
        _settings = State(wrappedValue: appSettings)
        _coordinator = State(
            initialValue: DictationCoordinator(
                speechService: SpeechAnalyzerService(settings: appSettings),
                cleaner: FoundationModelCleaner(),
                inserter: PasteboardTextInserter(),
                hotkeyMonitor: GlobalHotkeyMonitor(),
                permissions: PermissionManager(),
                settings: appSettings,
                historyStore: historyStore
            )
        )
    }

    var body: some Scene {
        MenuBarExtra("MacinTalk", systemImage: menuBarIcon) {
            MenuBarContent(
                coordinator: coordinator,
                readiness: readiness,
                onRefresh: { Task { await refreshReadiness() } },
                onQuit: { NSApplication.shared.terminate(nil) },
                onLaunch: {
                    await refreshReadinessOnLaunch()
                },
                shouldOpenSetup: { !didLaunchSetup && !readiness.isReadyForDictation },
                onDidOpenSetup: { didLaunchSetup = true }
            )
        }
        .menuBarExtraStyle(.window)

        WindowGroup("MacinTalk", id: "main") {
            MainWindowView(
                coordinator: coordinator,
                settings: settings,
                readiness: readiness,
                onRefreshReadiness: { Task { await refreshReadiness() } },
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
                }
            )
            .modelContainer(modelContainer)
        }
        .defaultLaunchBehavior(.presented)
        .commands {
            SidebarCommands()
        }

        Window("MacinTalk Setup", id: "setup") {
            SetupView(
                readiness: readiness,
                isPreparingSpeechAssets: coordinator.isPreparingSpeechAssets,
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
        .defaultLaunchBehavior(.suppressed)
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
    }

    @MainActor
    private func refreshReadiness() async {
        readiness = await coordinator.refreshReadiness()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
}
