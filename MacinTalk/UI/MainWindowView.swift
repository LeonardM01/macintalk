import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case home
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .settings: "gearshape"
        }
    }
}

struct MainWindowView: View {
    @Bindable var coordinator: DictationCoordinator
    @Bindable var settings: AppSettings
    let readiness: PermissionReadiness
    let onRefreshReadiness: () -> Void
    let onRequestMicrophone: () -> Void
    let onRequestInputMonitoring: () -> Void
    let onRequestPostEvent: () -> Void
    let onPrepareSpeechAssets: () -> Void

    @State private var selection: MainSection? = .home

    var body: some View {
        NavigationSplitView {
            List(MainSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selection ?? .home {
            case .home:
                HomeView(coordinator: coordinator)
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
        .frame(minWidth: 900, minHeight: 600)
    }
}
