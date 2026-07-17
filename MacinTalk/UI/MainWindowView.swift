import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case home
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

struct MainWindowView: View {
    @Bindable var coordinator: DictationCoordinator
    @Bindable var settings: AppSettings
    let readiness: PermissionReadiness?
    let onRefreshReadiness: () -> Void
    let onRequestMicrophone: () -> Void
    let onRequestInputMonitoring: () -> Void
    let onRequestPostEvent: () -> Void
    let onPrepareSpeechAssets: () -> Void

    @State private var selection: MainSection = .home
    @State private var selectedRecordID: UUID?

    var body: some View {
        ZStack {
            AppTheme.backdrop

            VStack(spacing: 0) {
                titlebar

                Group {
                    switch selection {
                    case .home:
                        HomeView(
                            coordinator: coordinator,
                            settings: settings,
                            selection: $selection,
                            selectedRecordID: $selectedRecordID
                        )
                    case .history:
                        HistoryView(settings: settings, selectedRecordID: $selectedRecordID)
                    case .settings:
                        SettingsView(
                            settings: settings,
                            coordinator: coordinator,
                            readiness: readiness,
                            onRequestMicrophone: onRequestMicrophone,
                            onRequestInputMonitoring: onRequestInputMonitoring,
                            onRequestPostEvent: onRequestPostEvent,
                            onPrepareSpeechAssets: onPrepareSpeechAssets,
                            onRefresh: onRefreshReadiness
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 860, minHeight: 600)
    }

    private var titlebar: some View {
        ZStack {
            HStack(spacing: 6) {
                Image(systemName: "mic.circle.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(AppTheme.accentLight)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                Text("MacinTalk")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .contentShape(Rectangle())
            .onTapGesture { selection = .home }

            HStack {
                Spacer()
                titlebarButton(section: .history)
                titlebarButton(section: .settings)
            }
            .padding(.trailing, 16)
        }
        .padding(.leading, 72)
        .padding(.vertical, 10)
    }

    private func titlebarButton(section: MainSection) -> some View {
        Button {
            selection = (selection == section) ? .home : section
        } label: {
            Image(systemName: section.systemImage)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 28, height: 28)
                .background(selection == section ? Color.white.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
