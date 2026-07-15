import AppKit
import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var coordinator: DictationCoordinator
    let readiness: PermissionReadiness
    let onRefresh: () -> Void
    let onQuit: () -> Void
    let onLaunch: () async -> Void
    let shouldOpenSetup: () -> Bool
    let onDidOpenSetup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(statusTitle)
                .font(.headline)

            Text(coordinator.snapshot.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !coordinator.snapshot.displayTranscript.isEmpty {
                Text(coordinator.snapshot.displayTranscript)
                    .font(.caption)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }

            Divider()

            Button("Open MacinTalk") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }

            Button("Setup…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "setup")
            }

            if coordinator.snapshot.phase == .recording {
                Button("Stop Dictation") {
                    coordinator.manualStop()
                }
            } else {
                Button("Start Dictation") {
                    coordinator.manualStart()
                }
                .disabled(!readiness.isReadyForDictation)
            }

            Button("Refresh Status", action: onRefresh)

            Divider()

            Button("Quit MacinTalk", action: onQuit)
        }
        .padding(8)
        .task {
            await onLaunch()
            if shouldOpenSetup() {
                onDidOpenSetup()
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "setup")
            }
        }
    }

    private var statusTitle: String {
        switch coordinator.snapshot.phase {
        case .idle:
            "Idle"
        case .recording:
            "Recording"
        case .cleaning:
            "Cleaning"
        case .inserting:
            "Inserting"
        case .failed:
            "Error"
        }
    }
}
