import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var coordinator: DictationCoordinator
    let readiness: PermissionReadiness
    let onRefresh: () -> Void
    let onQuit: () -> Void

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

            Button("Setup…") {
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
