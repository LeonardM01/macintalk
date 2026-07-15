import AppKit
import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var shortcut: DictationShortcut
    let onShortcutChanged: () -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 12) {
            Text(shortcut.displayString)
                .font(.body.monospaced())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 2)
                )

            Button(isRecording ? "Press shortcut…" : "Change") {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }

            Button("Reset") {
                shortcut = .default
                onShortcutChanged()
            }
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
