import SwiftUI

struct SetupView: View {
    let readiness: PermissionReadiness?
    let isPreparingSpeechAssets: Bool
    let onRequestMicrophone: () -> Void
    let onRequestInputMonitoring: () -> Void
    let onRequestPostEvent: () -> Void
    let onPrepareSpeechAssets: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MacinTalk Setup")
                .font(.title2)
            Text("Grant the permissions below, then use your shortcut anywhere to dictate.")
                .foregroundStyle(.secondary)

            PermissionsPanelView(
                readiness: readiness,
                isPreparingSpeechAssets: isPreparingSpeechAssets,
                onRequestMicrophone: onRequestMicrophone,
                onRequestInputMonitoring: onRequestInputMonitoring,
                onRequestPostEvent: onRequestPostEvent,
                onPrepareSpeechAssets: onPrepareSpeechAssets,
                onRefresh: onRefresh
            )
        }
        .padding(20)
        .frame(maxWidth: 420)
    }
}
