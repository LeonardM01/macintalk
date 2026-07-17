import AppKit
import SwiftData
import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var coordinator: DictationCoordinator
    @Bindable var settings: AppSettings
    let readiness: PermissionReadiness?
    let onRefresh: () -> Void
    let onQuit: () -> Void
    let onLaunch: () async -> Void
    let shouldOpenSetup: () -> Bool
    let onDidOpenSetup: () -> Void

    @Query(sort: \TranscriptionRecord.createdAt, order: .reverse) private var records: [TranscriptionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            primaryActionButton

            if let lastRecord = records.first {
                lastDictationSection(lastRecord)
            }

            footer
        }
        .padding(14)
        .frame(width: 300)
        .task {
            await onLaunch()
            if shouldOpenSetup() {
                onDidOpenSetup()
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "setup")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .overlay(
                        Circle().stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                    )
                Image(systemName: "mic.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.accentLight)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Hold \(settings.dictationShortcut.displayString) to dictate")
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.85))
            }

            Spacer()

            statusDot
        }
    }

    private var statusDot: some View {
        let color: Color
        if readiness == nil {
            color = AppTheme.textTertiary
        } else if readiness?.isReadyForDictation == true {
            color = AppTheme.success
        } else {
            color = AppTheme.warning
        }
        return Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.7), radius: 4)
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if coordinator.snapshot.phase == .recording {
            Button("Stop & Insert") {
                coordinator.manualStop()
            }
            .buttonStyle(.accent(AppTheme.danger))
            .frame(maxWidth: .infinity)
        } else {
            Button("Start Dictation") {
                coordinator.manualStart()
            }
            .buttonStyle(.accent(AppTheme.accent))
            .frame(maxWidth: .infinity)
            .disabled(!(readiness?.isReadyForDictation ?? false))
        }
    }

    private func lastDictationSection(_ record: TranscriptionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LAST DICTATION · \(record.createdAt.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(AppTheme.textTertiary)

            Text(record.previewText)
                .font(.system(size: 11.5))
                .foregroundStyle(AppTheme.textPrimary.opacity(0.75))
                .lineLimit(2)
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
        }
    }

    private var footer: some View {
        HStack {
            Text("\(usageStats.wordsToday) words · \(usageStats.minutesSavedToday) min saved today")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textSecondary.opacity(0.5))

            Spacer()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)

            Menu {
                Button("Open MacinTalk") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                Button("Setup…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "setup")
                }
                Button("Refresh Status", action: onRefresh)
                Divider()
                Button("Quit MacinTalk", action: onQuit)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var usageStats: UsageStats {
        UsageStatsCalculator.stats(for: records.map {
            UsageStatsCalculator.Entry(createdAt: $0.createdAt, wordCount: $0.wordCount, durationSeconds: $0.durationSeconds)
        })
    }

    private var statusTitle: String {
        switch coordinator.snapshot.phase {
        case .idle:
            "Idle"
        case .recording:
            "Listening…"
        case .cleaning:
            "Cleaning"
        case .inserting:
            "Inserting"
        case .failed:
            "Error"
        }
    }
}
