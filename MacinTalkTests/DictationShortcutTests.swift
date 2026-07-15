import Foundation
import Testing
@testable import MacinTalk

struct DictationShortcutTests {
    @Test func defaultShortcutDisplayString() {
        let shortcut = DictationShortcut.default
        #expect(shortcut.displayString == "⌃⌥Space")
        #expect(shortcut.promptMessage == "Hold ⌃⌥Space to dictate")
    }

    @Test func shortcutPersistenceRoundTrip() throws {
        let shortcut = DictationShortcut(keyCode: 8, usesControl: true, usesOption: false, usesCommand: false, usesShift: true)
        let data = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(DictationShortcut.self, from: data)
        #expect(decoded == shortcut)
    }
}
