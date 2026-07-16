import SwiftUI

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
