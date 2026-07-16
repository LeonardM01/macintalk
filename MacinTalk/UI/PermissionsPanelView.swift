import SwiftUI

struct PermissionsPanelView: View {
    let readiness: PermissionReadiness?
    let isPreparingSpeechAssets: Bool
    let onRequestMicrophone: () -> Void
    let onRequestInputMonitoring: () -> Void
    let onRequestPostEvent: () -> Void
    let onPrepareSpeechAssets: () -> Void
    let onRefresh: () -> Void

    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(spacing: 0) {
                microphoneRow
                inputMonitoringRow
                accessibilityRow
                speechLanguageRow
                speechAssetsRow
                appleIntelligenceRow
            }

            footerBanner
                .padding(.top, 14)
        }
        .onChange(of: readiness) { _, _ in
            isRefreshing = false
        }
    }

    private var header: some View {
        HStack {
            Text("Permissions & Setup")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Button {
                isRefreshing = true
                onRefresh()
            } label: {
                Text(isRefreshing ? "Checking…" : "Refresh")
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 12)
    }

    private var microphoneRow: some View {
        row(
            glyph: glyph(for: readiness?.microphoneGranted),
            title: "Microphone",
            description: "Required to capture your voice.",
            actionTitle: readiness == nil ? nil : (readiness?.microphoneGranted == true ? nil : "Grant Access"),
            action: onRequestMicrophone
        )
    }

    private var inputMonitoringRow: some View {
        row(
            glyph: glyph(for: readiness?.inputMonitoringGranted),
            title: "Input Monitoring",
            description: "Required for the global hold-to-talk hotkey.",
            actionTitle: readiness == nil ? nil : (readiness?.inputMonitoringGranted == true ? nil : "Open Settings…"),
            action: onRequestInputMonitoring
        )
    }

    private var accessibilityRow: some View {
        row(
            glyph: glyph(for: readiness?.postEventGranted),
            title: "Accessibility (Post Event)",
            description: "Required to paste text into other apps.",
            actionTitle: readiness == nil ? nil : (readiness?.postEventGranted == true ? nil : "Open Settings…"),
            action: onRequestPostEvent
        )
    }

    private var speechLanguageRow: some View {
        row(
            glyph: glyph(for: readiness?.speechLocaleSupported),
            title: "Speech Language",
            description: speechLocaleDetail,
            actionTitle: nil,
            action: onRefresh
        )
    }

    @ViewBuilder
    private var speechAssetsRow: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: glyph(for: readiness?.speechAssetsInstalled))
                .font(.system(size: 13))
                .foregroundStyle(color(for: readiness?.speechAssetsInstalled))

            VStack(alignment: .leading, spacing: 3) {
                Text("Speech Assets")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(speechAssetsDetail)
                    .font(.system(size: 11))
                    .lineSpacing(11 * 0.4)
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.45))

                if isPreparingSpeechAssets {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Downloading…")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()

            if readiness != nil, readiness?.speechAssetsInstalled == false {
                Button(isPreparingSpeechAssets ? "Downloading…" : "Download Now") {
                    onPrepareSpeechAssets()
                }
                .disabled(isPreparingSpeechAssets)
                .font(.system(size: 11.5, weight: .medium))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
        }
    }

    private var appleIntelligenceRow: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: readiness?.appleIntelligenceAvailable == true ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(readiness == nil ? AppTheme.textTertiary : (readiness?.appleIntelligenceAvailable == true ? AppTheme.success : AppTheme.textSecondary))

            VStack(alignment: .leading, spacing: 3) {
                Text("Apple Intelligence")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(appleIntelligenceDetail)
                    .font(.system(size: 11))
                    .lineSpacing(11 * 0.4)
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.45))
            }

            Spacer()

            if readiness != nil {
                Button("Refresh", action: onRefresh)
                    .font(.system(size: 11.5, weight: .medium))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func row(
        glyph: String,
        title: String,
        description: String,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: glyph)
                .font(.system(size: 13))
                .foregroundStyle(color(for: glyphState(for: title)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(description)
                    .font(.system(size: 11))
                    .lineSpacing(11 * 0.4)
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.45))
            }

            Spacer()

            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(.system(size: 11.5, weight: .medium))
            } else if readiness == nil {
                Text("Checking…")
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
        }
    }

    private func glyphState(for title: String) -> Bool? {
        switch title {
        case "Microphone": readiness?.microphoneGranted
        case "Input Monitoring": readiness?.inputMonitoringGranted
        case "Accessibility (Post Event)": readiness?.postEventGranted
        case "Speech Language": readiness?.speechLocaleSupported
        default: nil
        }
    }

    private func glyph(for granted: Bool?) -> String {
        guard let granted else { return "circle.dotted" }
        return granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    }

    private func color(for granted: Bool?) -> Color {
        guard let granted else { return AppTheme.textTertiary }
        return granted ? AppTheme.success : AppTheme.warning
    }

    private var speechLocaleDetail: String {
        guard let readiness else { return "Checking your speech recognition locale…" }
        if readiness.speechLocaleUsesFallback {
            return "Using \(readiness.speechLocaleLabel) because \(readiness.preferredLocaleLabel) isn't supported yet. You can still dictate in any language."
        }
        return "Using \(readiness.speechLocaleLabel) for speech recognition."
    }

    private var speechAssetsDetail: String {
        guard let readiness else { return "Checking speech recognition assets…" }
        if readiness.speechAssetsInstalled {
            return "Installed for \(readiness.speechLocaleLabel)."
        }
        return "One-time download for \(readiness.speechLocaleLabel). Tap Download Now and wait for the checkmark — this is required before dictation works."
    }

    private var appleIntelligenceDetail: String {
        guard let readiness else { return "Checking Apple Intelligence availability…" }
        return readiness.appleIntelligenceAvailable
            ? "Available for transcript cleanup."
            : "Unavailable; raw transcripts will be pasted."
    }

    @ViewBuilder
    private var footerBanner: some View {
        if let readiness {
            if readiness.isReadyForDictation {
                HStack(spacing: 6) {
                    Text("✓ Ready to dictate")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.success)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AppTheme.success.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(AppTheme.success.opacity(0.25), lineWidth: 1)
                )
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(readiness.blockingIssues, id: \.self) { issue in
                        Text(issue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.warning)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AppTheme.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(AppTheme.warning.opacity(0.25), lineWidth: 1)
                )
            }
        } else {
            HStack(spacing: 6) {
                Text("Checking permissions…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
