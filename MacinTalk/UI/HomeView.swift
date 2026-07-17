import AppKit
import SwiftData
import SwiftUI

struct HomeView: View {
    @Bindable var coordinator: DictationCoordinator
    @Bindable var settings: AppSettings
    @Binding var selection: MainSection
    @Binding var selectedRecordID: UUID?

    @Query(sort: \TranscriptionRecord.createdAt, order: .reverse) private var records: [TranscriptionRecord]

    @State private var activeToastEvent: InsertionEvent?
    @State private var toastDismissTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    switch coordinator.snapshot.phase {
                    case .idle:
                        idleContent
                    case .recording:
                        recordingContent
                    case .cleaning, .inserting:
                        busyContent
                    case .failed:
                        failedContent
                    }
                }
                .offset(y: -14)

                Spacer()

                if !recentRecords.isEmpty {
                    recentList
                }
            }

            if let activeToastEvent {
                ToastView(message: activeToastEvent.message, isSuccess: activeToastEvent.succeeded)
                    .padding(.bottom, 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(escapeShortcut)
        .onChange(of: coordinator.lastInsertionEvent) { _, newValue in
            guard let newValue else { return }
            toastDismissTask?.cancel()
            withAnimation(.easeOut(duration: 0.25)) {
                activeToastEvent = newValue
            }
            toastDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1600))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    activeToastEvent = nil
                }
            }
        }
    }

    private var recentRecords: [TranscriptionRecord] {
        Array(records.prefix(3))
    }

    private var usageStats: UsageStats {
        UsageStatsCalculator.stats(for: records.map {
            UsageStatsCalculator.Entry(createdAt: $0.createdAt, wordCount: $0.wordCount, durationSeconds: $0.durationSeconds)
        })
    }

    @ViewBuilder
    private var escapeShortcut: some View {
        if coordinator.snapshot.phase == .recording {
            Button("") {
                coordinator.cancelRecording()
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .frame(width: 0, height: 0)
        }
    }

    private var idleContent: some View {
        VStack(spacing: 16) {
            DictationOrb(isRecording: false)

            Text("Ready to dictate")
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 6) {
                Text("Hold")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                ShortcutKeycapsView(shortcut: settings.dictationShortcut)
                Text("anywhere")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Button("Start Dictation") {
                coordinator.manualStart()
            }
            .buttonStyle(.accent(AppTheme.accent))

            Text("Today · \(usageStats.wordsToday) words · \(usageStats.minutesSavedToday) min saved · \(settings.writingStyle.title) style")
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textTertiary)
        }
    }

    private var recordingContent: some View {
        VStack(spacing: 16) {
            DictationOrb(isRecording: true)

            Text("Listening…")
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Release \(settings.dictationShortcut.displayString) or click Stop to insert · Esc to cancel")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)

            liveTranscriptBox

            Button("Stop & Insert") {
                coordinator.manualStop()
            }
            .buttonStyle(.accent(AppTheme.danger))
        }
    }

    private var liveTranscriptBox: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(coordinator.snapshot.displayTranscript)
                .font(.system(size: 13.5))
                .lineSpacing(13.5 * 0.55)
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(AppTheme.accent)
                .frame(width: 2, height: 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(width: 560, alignment: .leading)
        .frame(minHeight: 64)
        .glassCard()
    }

    private var busyContent: some View {
        VStack(spacing: 16) {
            DictationOrb(isRecording: false)

            Text(coordinator.snapshot.statusMessage)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var failedContent: some View {
        VStack(spacing: 16) {
            DictationOrb(isRecording: false)

            Text("Ready to dictate")
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(AppTheme.textPrimary)

            Text(coordinator.snapshot.statusMessage)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.danger)

            Button("Start Dictation") {
                coordinator.manualStart()
            }
            .buttonStyle(.accent(AppTheme.accent))
        }
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("RECENT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                Button("Show all history") {
                    selection = .history
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(Color(red: 0x7c / 255, green: 0xb8 / 255, blue: 1))
            }

            VStack(spacing: 0) {
                ForEach(recentRecords) { record in
                    RecentRow(record: record) {
                        selectedRecordID = record.id
                        selection = .history
                    }
                }
            }
        }
        .padding(.horizontal, 34)
        .padding(.bottom, 22)
    }
}

private struct RecentRow: View {
    let record: TranscriptionRecord
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Text(record.createdAt, style: .time)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.4))
                    .frame(width: 38, alignment: .leading)

                Text(record.previewText)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                StylePill(title: record.writingStyle.title)

                if record.insertionSucceeded == true {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.success)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
            .background(isHovering ? Color.white.opacity(0.03) : Color.clear)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
