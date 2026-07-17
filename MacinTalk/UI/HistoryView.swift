import AppKit
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Bindable var settings: AppSettings
    @Binding var selectedRecordID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionRecord.createdAt, order: .reverse) private var records: [TranscriptionRecord]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            leftRail
                .frame(width: 360)

            if let record = selectedRecord {
                detail(for: record)
            }
        }
        .padding(.top, 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .onAppear {
            if selectedRecordID == nil {
                selectedRecordID = records.first?.id
            }
        }
    }

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' HH:mm"
        return formatter
    }()

    private var selectedRecord: TranscriptionRecord? {
        guard let selectedRecordID else { return nil }
        return records.first { $0.id == selectedRecordID }
    }

    @ViewBuilder
    private var leftRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if records.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                            let label = HistoryGrouping.label(for: record.createdAt)
                            let previousLabel = index > 0 ? HistoryGrouping.label(for: records[index - 1].createdAt) : nil

                            if label != previousLabel {
                                Text(label.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.6)
                                    .foregroundStyle(Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.35))
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                                    .padding(.horizontal, 2)
                            }

                            HistoryRow(record: record, isSelected: selectedRecordID == record.id) {
                                selectedRecordID = record.id
                            }
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("History")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            if !records.isEmpty {
                ClearAllButton {
                    clearAllHistory()
                }
            }
        }
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No dictations yet.")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.textTertiary)
            Text("Hold \(settings.dictationShortcut.displayString) anywhere to start.")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private func detail(for record: TranscriptionRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.createdAt, formatter: Self.detailDateFormatter)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)

                            HStack(spacing: 8) {
                                StylePill(title: record.writingStyle.title)

                                if let succeeded = record.insertionSucceeded {
                                    if succeeded {
                                        Text("✓ Inserted into active app")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(AppTheme.success)
                                    } else {
                                        Text("Insertion failed: \(record.insertionErrorMessage ?? "Unknown error")")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(AppTheme.danger)
                                    }
                                }
                            }
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            CopyCleanedButton(record: record)
                                .id(record.id)
                            DeleteRecordButton {
                                deleteRecord(record)
                            }
                        }
                    }

                    textSection(title: "CLEANED TEXT", body: record.cleanedText, labelColor: AppTheme.accentLight, dim: false)
                    textSection(title: "RAW TRANSCRIPT", body: record.rawText, labelColor: AppTheme.textTertiary, dim: true)
                }
            }

            HStack(spacing: 14) {
                Text("\(record.wordCount) words · \(record.writingStyle.title) style")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.4))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard(cornerRadius: 14)
    }

    private func textSection(title: String, body: String, labelColor: Color, dim: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.75)
                .foregroundStyle(labelColor)

            Text(body)
                .font(.system(size: dim ? 13 : 13.5))
                .lineSpacing((dim ? 13 : 13.5) * 0.6)
                .foregroundStyle(dim ? Color(red: 240 / 255, green: 240 / 255, blue: 245 / 255).opacity(0.55) : Color(red: 240 / 255, green: 240 / 255, blue: 245 / 255))
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, dim ? 15 : 15)
        .padding(.vertical, 17)
        .background(Color.white.opacity(dim ? 0.025 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(dim ? 0.05 : 0.08), lineWidth: 1)
        )
    }

    private func deleteRecord(_ record: TranscriptionRecord) {
        let deletedID = record.id
        let currentIndex = records.firstIndex { $0.id == deletedID }
        modelContext.delete(record)
        try? modelContext.save()

        if selectedRecordID == deletedID {
            if let currentIndex {
                let remaining = records.filter { $0.id != deletedID }
                if currentIndex < remaining.count {
                    selectedRecordID = remaining[currentIndex].id
                } else {
                    selectedRecordID = remaining.last?.id
                }
            } else {
                selectedRecordID = nil
            }
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

private struct ClearAllButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text("Clear All")
                .font(.system(size: 11.5))
                .foregroundStyle(isHovering ? AppTheme.dangerLight : AppTheme.textSecondary)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct HistoryRow: View {
    let record: TranscriptionRecord
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                Text(record.previewText)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color(red: 240 / 255, green: 240 / 255, blue: 245 / 255))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Text(record.createdAt, style: .time)
                        .font(.system(size: 10.5))
                        .monospacedDigit()

                    Text("·")
                        .font(.system(size: 10.5))

                    StylePill(title: record.writingStyle.title)

                    if record.insertionSucceeded == true {
                        Text("✓ inserted")
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.success)
                    }
                }
                .opacity(0.5)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppTheme.accent.opacity(0.18) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CopyCleanedButton: View {
    let record: TranscriptionRecord
    @State private var didCopy = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(record.cleanedText, forType: .string)
            didCopy = true
            Task {
                try? await Task.sleep(for: .milliseconds(1400))
                didCopy = false
            }
        } label: {
            Text(didCopy ? "Copied ✓" : "Copy Cleaned")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct DeleteRecordButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Delete")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(AppTheme.dangerLight)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(AppTheme.dangerLight.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(AppTheme.dangerLight.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
