import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var coordinator: DictationCoordinator
    let readiness: PermissionReadiness
    let onRequestMicrophone: () -> Void
    let onRequestInputMonitoring: () -> Void
    let onRequestPostEvent: () -> Void
    let onPrepareSpeechAssets: () -> Void
    let onRefresh: () -> Void

    @State private var inputDevices = AudioInputDeviceDiscovery.availableDevices()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.largeTitle)

                GroupBox("Dictation Shortcut") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hold this shortcut anywhere to start dictating. Release to stop and insert text.")
                            .foregroundStyle(.secondary)

                        ShortcutRecorderView(shortcut: $settings.dictationShortcut) {
                            coordinator.applyShortcutChange()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Microphone") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose which microphone MacinTalk uses for dictation.")
                            .foregroundStyle(.secondary)

                        Picker("Input Device", selection: $settings.selectedInputDeviceID) {
                            ForEach(inputDevices) { device in
                                Text(device.name).tag(device.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: settings.selectedInputDeviceID) { _, _ in
                            coordinator.applyInputDeviceChange()
                        }

                        HStack {
                            Text(selectedDeviceLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Refresh Devices") {
                                refreshInputDevices()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Writing Style") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose how Apple Intelligence cleans up your dictated text.")
                            .foregroundStyle(.secondary)

                        Picker("Writing Style", selection: $settings.writingStyle) {
                            ForEach(WritingStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)

                        ForEach(WritingStyle.allCases) { style in
                            if settings.writingStyle == style {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(style.subtitle)
                                        .font(.callout)
                                    Text("Example: \(style.exampleDescription)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Permissions & Setup") {
                    SetupView(
                        embedded: true,
                        readiness: readiness,
                        isPreparingSpeechAssets: coordinator.isPreparingSpeechAssets,
                        onRequestMicrophone: onRequestMicrophone,
                        onRequestInputMonitoring: onRequestInputMonitoring,
                        onRequestPostEvent: onRequestPostEvent,
                        onPrepareSpeechAssets: onPrepareSpeechAssets,
                        onRefresh: onRefresh
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            refreshInputDevices()
        }
    }

    private var selectedDeviceLabel: String {
        if settings.selectedInputDeviceID.isEmpty {
            return "Using the system default microphone."
        }
        if let device = inputDevices.first(where: { $0.id == settings.selectedInputDeviceID }) {
            return "Selected: \(device.name)"
        }
        return "Previously selected device is unavailable. Using system default."
    }

    private func refreshInputDevices() {
        inputDevices = AudioInputDeviceDiscovery.availableDevices()
        if !settings.selectedInputDeviceID.isEmpty,
           !inputDevices.contains(where: { $0.id == settings.selectedInputDeviceID }) {
            settings.selectedInputDeviceID = AudioInputDevice.systemDefaultID
            coordinator.applyInputDeviceChange()
        }
    }
}
