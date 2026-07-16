import SwiftUI

struct KeycapView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 2)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 1)
            }
    }
}

struct ShortcutKeycapsView: View {
    let shortcut: DictationShortcut

    private var labels: [String] {
        var parts: [String] = []
        if shortcut.usesControl { parts.append("⌃") }
        if shortcut.usesOption { parts.append("⌥") }
        if shortcut.usesShift { parts.append("⇧") }
        if shortcut.usesCommand { parts.append("⌘") }
        parts.append(DictationShortcut.keyDisplayName(for: shortcut.keyCode))
        return parts
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                KeycapView(label: label)
            }
        }
    }
}
