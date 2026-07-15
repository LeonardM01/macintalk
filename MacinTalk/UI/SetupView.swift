import SwiftUI

struct SetupView: View {
    var embedded = false
    let readiness: PermissionReadiness
    let isPreparingSpeechAssets: Bool
    let onRequestMicrophone: () -> Void
    let onRequestInputMonitoring: () -> Void
    let onRequestPostEvent: () -> Void
    let onPrepareSpeechAssets: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !embedded {
                Text("MacinTalk Setup")
                    .font(.title2)
                Text("Grant the permissions below, then use your shortcut anywhere to dictate.")
                    .foregroundStyle(.secondary)
            }

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
                title: "Speech Language",
                detail: speechLocaleDetail,
                isGranted: readiness.speechLocaleSupported,
                actionTitle: "Refresh",
                action: onRefresh
            )

            speechAssetsRow

            permissionRow(
                title: "Apple Intelligence",
                detail: readiness.appleIntelligenceAvailable
                    ? "Available for transcript cleanup."
                    : "Unavailable; raw transcripts will be pasted.",
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
        .padding(embedded ? 0 : 20)
        .frame(maxWidth: embedded ? .infinity : 420)
    }

    private var speechLocaleDetail: String {
        if readiness.speechLocaleUsesFallback {
            return "Using \(readiness.speechLocaleLabel) because \(readiness.preferredLocaleLabel) isn't supported yet. You can still dictate in any language."
        }
        return "Using \(readiness.speechLocaleLabel) for speech recognition."
    }

    @ViewBuilder
    private var speechAssetsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: readiness.speechAssetsInstalled ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(readiness.speechAssetsInstalled ? .green : .orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Speech Assets")
                    .font(.headline)
                Text(speechAssetsDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if isPreparingSpeechAssets {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Downloading speech models…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()

            if !readiness.speechAssetsInstalled {
                Button(isPreparingSpeechAssets ? "Downloading…" : "Download Now") {
                    onPrepareSpeechAssets()
                }
                .disabled(isPreparingSpeechAssets)
            }
        }
    }

    private var speechAssetsDetail: String {
        if readiness.speechAssetsInstalled {
            return "Installed for \(readiness.speechLocaleLabel)."
        }
        return "One-time download for \(readiness.speechLocaleLabel). Tap Download Now and wait for the checkmark — this is required before dictation works."
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
