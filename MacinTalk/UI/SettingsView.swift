import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var coordinator: DictationCoordinator
    let readiness: PermissionReadiness?
    let onRequestMicrophone: () -> Void
    let onRequestInputMonitoring: () -> Void
    let onRequestPostEvent: () -> Void
    let onPrepareSpeechAssets: () -> Void
    let onRefresh: () -> Void

    @State private var inputDevices = AudioInputDeviceDiscovery.availableDevices()
    @State private var isRefreshingDevices = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(size: 21, weight: .bold))
                    .tracking(-0.21)
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(alignment: .top, spacing: 14) {
                    leftColumn
                        .frame(maxWidth: .infinity)

                    rightColumn
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 30)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            refreshInputDevices()
        }
    }

    private var leftColumn: some View {
        VStack(spacing: 14) {
            shortcutCard
            microphoneCard
            writingStyleCard
        }
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            PermissionsPanelView(
                readiness: readiness,
                isPreparingSpeechAssets: coordinator.isPreparingSpeechAssets,
                onRequestMicrophone: onRequestMicrophone,
                onRequestInputMonitoring: onRequestInputMonitoring,
                onRequestPostEvent: onRequestPostEvent,
                onPrepareSpeechAssets: onPrepareSpeechAssets,
                onRefresh: onRefresh
            )
        }
        .padding(15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard()
    }

    private var shortcutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dictation Shortcut")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Hold anywhere to start dictating. Release to stop and insert text.")
                .font(.system(size: 11.5))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.85))

            ShortcutRecorderView(shortcut: $settings.dictationShortcut) {
                coordinator.applyShortcutChange()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .glassCard()
    }

    private var microphoneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Microphone")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    refreshInputDevices()
                } label: {
                    Text(isRefreshingDevices ? "Refreshing…" : "Refresh Devices")
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Text("Choose which microphone MacinTalk uses for dictation.")
                .font(.system(size: 11.5))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.85))

            Picker("", selection: $settings.selectedInputDeviceID) {
                ForEach(inputDevices) { device in
                    Text(device.name).tag(device.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .font(.system(size: 12.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .onChange(of: settings.selectedInputDeviceID) { _, _ in
                coordinator.applyInputDeviceChange()
            }

            Text(selectedDeviceLabel)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .glassCard()
    }

    private var writingStyleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Writing Style")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Choose how Apple Intelligence cleans up your dictated text.")
                .font(.system(size: 11.5))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.85))

            WritingStyleSegmentedControl(selection: $settings.writingStyle)

            VStack(alignment: .leading, spacing: 6) {
                Text(settings.writingStyle.subtitle)
                    .font(.system(size: 12))
                    .lineSpacing(12 * 0.45)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
                Text("Example: \(settings.writingStyle.exampleDescription)")
                    .font(.system(size: 11))
                    .italic()
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.42))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .glassCard()
    }

    private var selectedDeviceLabel: String {
        if settings.selectedInputDeviceID.isEmpty {
            return "Using the system default microphone."
        }
        if let device = inputDevices.first(where: { $0.id == settings.selectedInputDeviceID }) {
            return "Using \(device.name)."
        }
        return "Previously selected device is unavailable. Using system default."
    }

    private func refreshInputDevices() {
        isRefreshingDevices = true
        inputDevices = AudioInputDeviceDiscovery.availableDevices()
        if !settings.selectedInputDeviceID.isEmpty,
           !inputDevices.contains(where: { $0.id == settings.selectedInputDeviceID }) {
            settings.selectedInputDeviceID = AudioInputDevice.systemDefaultID
            coordinator.applyInputDeviceChange()
        }
        isRefreshingDevices = false
    }
}

private struct WritingStyleSegmentedControl: View {
    @Binding var selection: WritingStyle

    var body: some View {
        HStack(spacing: 2) {
            ForEach(WritingStyle.allCases) { style in
                chip(for: style)
            }
        }
        .padding(2)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func chip(for style: WritingStyle) -> some View {
        let isSelected = selection == style
        return Button {
            selection = style
        } label: {
            Text(style.title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.65))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(isSelected ? AppTheme.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: isSelected ? AppTheme.accent.opacity(0.4) : .clear, radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}
