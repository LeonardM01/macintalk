import AppKit
import SwiftUI
import SwiftData

struct HomeView: View {
    @Bindable var coordinator: DictationCoordinator
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionRecord.createdAt, order: .reverse) private var records: [TranscriptionRecord]
    @State private var selectedRecordID: UUID?

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 16) {
                statusCard

                HStack {
                    Text("History")
                        .font(.title2)
                        .bold()
                    Spacer()
                    if !records.isEmpty {
                        Button("Clear All", role: .destructive) {
                            clearAllHistory()
                        }
                    }
                }

                if records.isEmpty {
                    ContentUnavailableView(
                        "No transcriptions yet",
                        systemImage: "text.bubble",
                        description: Text("Hold Control+Option+Space to dictate. Your cleaned transcripts will appear here.")
                    )
                } else {
                    List(records, selection: $selectedRecordID) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.previewText)
                                .lineLimit(2)
                            HStack(spacing: 8) {
                                Text(record.createdAt, style: .date)
                                Text(record.createdAt, style: .time)
                                Text(record.writingStyle.title)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                                if let succeeded = record.insertionSucceeded {
                                    Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(succeeded ? .green : .orange)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .tag(record.id)
                    }
                }
            }
            .padding()
            .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        } detail: {
            if let record = selectedRecord {
                TranscriptionDetailView(record: record, onDelete: {
                    deleteRecord(record)
                })
            } else {
                ContentUnavailableView(
                    "Select a transcription",
                    systemImage: "doc.text",
                    description: Text("Choose an item from the list to view raw and cleaned text.")
                )
            }
        }
        .onChange(of: records.count) { _, _ in
            if let selectedRecordID, !records.contains(where: { $0.id == selectedRecordID }) {
                self.selectedRecordID = records.first?.id
            } else if selectedRecordID == nil {
                selectedRecordID = records.first?.id
            }
        }
        .onAppear {
            if selectedRecordID == nil {
                selectedRecordID = records.first?.id
            }
        }
    }

    private var selectedRecord: TranscriptionRecord? {
        guard let selectedRecordID else { return nil }
        return records.first { $0.id == selectedRecordID }
    }

    private var statusCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(statusTitle, systemImage: statusIcon)
                        .font(.headline)
                    Spacer()
                    if coordinator.snapshot.phase == .recording {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text(coordinator.snapshot.statusMessage)
                    .foregroundStyle(.secondary)

                if !coordinator.snapshot.displayTranscript.isEmpty {
                    Text(coordinator.snapshot.displayTranscript)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                }

                HStack {
                    if coordinator.snapshot.phase == .recording {
                        Button("Stop Dictation") {
                            coordinator.manualStop()
                        }
                    } else {
                        Button("Start Dictation") {
                            coordinator.manualStart()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Live Dictation")
        }
    }

    private var statusTitle: String {
        switch coordinator.snapshot.phase {
        case .idle: "Idle"
        case .recording: "Recording"
        case .cleaning: "Cleaning"
        case .inserting: "Inserting"
        case .failed: "Error"
        }
    }

    private var statusIcon: String {
        switch coordinator.snapshot.phase {
        case .idle: "mic"
        case .recording: "mic.fill"
        case .cleaning, .inserting: "ellipsis.circle"
        case .failed: "exclamationmark.triangle"
        }
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

private struct TranscriptionDetailView: View {
    let record: TranscriptionRecord
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                        Text(record.writingStyle.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Copy Cleaned") {
                        copyToClipboard(record.cleanedText)
                    }
                    Button("Delete", role: .destructive, action: onDelete)
                }

                if let succeeded = record.insertionSucceeded {
                    Label(
                        succeeded ? "Inserted into active app" : "Insertion failed",
                        systemImage: succeeded ? "checkmark.circle" : "xmark.circle"
                    )
                    .foregroundStyle(succeeded ? .green : .orange)

                    if let message = record.insertionErrorMessage, !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                GroupBox("Cleaned Text") {
                    Text(record.cleanedText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Raw Transcript") {
                    Text(record.rawText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
