import SwiftUI

struct SetupView: View {
    let readiness: PermissionReadiness
    let onRequestMicrophone: () -> Void
    let onRequestInputMonitoring: () -> Void
    let onRequestPostEvent: () -> Void
    let onPrepareSpeechAssets: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MacinTalk Setup")
                .font(.title2)
                .bold()

            Text("Grant the permissions below, then hold Control+Option+Space anywhere to dictate.")
                .foregroundStyle(.secondary)

            permissionRow(
                title: "Microphone",
                detail: "Required to capture your voice.",
                isGranted: readiness.microphoneGranted,
                actionTitle: "Request Access",
                action: onRequestMicrophone
            )

            permissionRow(
                title: "Input Monitoring",
                detail: "Required for the global hold-to-talk hotkey.",
                isGranted: readiness.inputMonitoringGranted,
                actionTitle: "Open Settings",
                action: onRequestInputMonitoring
            )

            permissionRow(
                title: "Accessibility (Post Event)",
                detail: "Required to paste text into other apps.",
                isGranted: readiness.postEventGranted,
                actionTitle: "Open Settings",
                action: onRequestPostEvent
            )

            permissionRow(
                title: "Speech Locale",
                detail: readiness.speechLocaleSupported ? "Supported for \(Locale.current.identifier)" : "Current locale is not supported.",
                isGranted: readiness.speechLocaleSupported,
                actionTitle: "Refresh",
                action: onRefresh
            )

            permissionRow(
                title: "Speech Assets",
                detail: readiness.speechAssetsInstalled ? "Installed for your locale." : "Download on first dictation or prepare now.",
                isGranted: readiness.speechAssetsInstalled,
                actionTitle: "Prepare",
                action: onPrepareSpeechAssets
            )

            permissionRow(
                title: "Apple Intelligence",
                detail: readiness.appleIntelligenceAvailable ? "Available for transcript cleanup." : "Unavailable; raw transcripts will be pasted.",
                isGranted: readiness.appleIntelligenceAvailable,
                actionTitle: "Refresh",
                action: onRefresh
            )

            if readiness.isReadyForDictation {
                Label("Ready to dictate", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text(readiness.blockingIssues.joined(separator: "\n"))
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("Refresh", action: onRefresh)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        detail: String,
        isGranted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(isGranted ? .green : .orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }

            Spacer()

            if !isGranted {
                Button(actionTitle, action: action)
            }
        }
    }
}
