import AppKit
import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var shortcut: DictationShortcut
    let onShortcutChanged: () -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 10) {
            ShortcutKeycapsView(shortcut: shortcut)

            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? "Press keys…" : "Change")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(isRecording ? AppTheme.accentLight : AppTheme.textPrimary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(isRecording ? AppTheme.accent.opacity(0.15) : Color.white.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(isRecording ? AppTheme.accent.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button("Reset") {
                shortcut = .default
                onShortcutChanged()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5))
            .foregroundStyle(AppTheme.textSecondary)
            .disabled(shortcut == .default)
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if let captured = DictationShortcut.from(event: event) {
                shortcut = captured
                onShortcutChanged()
                stopRecording()
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
