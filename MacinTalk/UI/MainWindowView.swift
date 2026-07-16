import SwiftData
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
    let readiness: PermissionReadiness
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
                        HistoryView(selectedRecordID: $selectedRecordID)
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

struct HistoryView: View {
    @Binding var selectedRecordID: UUID?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionRecord.createdAt, order: .reverse) private var records: [TranscriptionRecord]

    var body: some View {
        HStack(spacing: 0) {
            list
                .frame(width: 320)

            Divider()
                .overlay(AppTheme.cardBorder)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if selectedRecordID == nil {
                selectedRecordID = records.first?.id
            }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if !records.isEmpty {
                    Button("Clear All", role: .destructive) {
                        clearAllHistory()
                    }
                    .font(.system(size: 11.5))
                }
            }
            .padding(16)

            if records.isEmpty {
                ContentUnavailableView(
                    "No transcriptions yet",
                    systemImage: "text.bubble",
                    description: Text("Your cleaned transcripts will appear here.")
                )
                .foregroundStyle(AppTheme.textSecondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(records) { record in
                            Button {
                                selectedRecordID = record.id
                            } label: {
                                row(for: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func row(for record: TranscriptionRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.previewText)
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
                StylePill(title: record.writingStyle.title)
                if let succeeded = record.insertionSucceeded {
                    Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(succeeded ? AppTheme.success : AppTheme.warning)
                        .font(.system(size: 11))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectedRecordID == record.id ? Color.white.opacity(0.06) : Color.clear)
    }

    @ViewBuilder
    private var detail: some View {
        if let record = selectedRecord {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            StylePill(title: record.writingStyle.title)
                        }
                        Spacer()
                        Button("Delete", role: .destructive) {
                            deleteRecord(record)
                        }
                    }

                    if let succeeded = record.insertionSucceeded {
                        Label(
                            succeeded ? "Inserted into active app" : "Insertion failed",
                            systemImage: succeeded ? "checkmark.circle" : "xmark.circle"
                        )
                        .foregroundStyle(succeeded ? AppTheme.success : AppTheme.warning)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cleaned Text")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(record.cleanedText)
                            .foregroundStyle(AppTheme.textPrimary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassCard()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Raw Transcript")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(record.rawText)
                            .foregroundStyle(AppTheme.textSecondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassCard()
                }
                .padding(24)
            }
        } else {
            ContentUnavailableView(
                "Select a transcription",
                systemImage: "doc.text",
                description: Text("Choose an item from the list to view raw and cleaned text.")
            )
            .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var selectedRecord: TranscriptionRecord? {
        guard let selectedRecordID else { return nil }
        return records.first { $0.id == selectedRecordID }
    }

    private func deleteRecord(_ record: TranscriptionRecord) {
        modelContext.delete(record)
        try? modelContext.save()
        if selectedRecordID == record.id {
            selectedRecordID = nil
        }
    }

    private func clearAllHistory() {
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
        selectedRecordID = nil
    }
}
