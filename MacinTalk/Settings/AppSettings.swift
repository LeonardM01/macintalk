import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    private static let writingStyleKey = "writingStyle"
    private static let shortcutKey = "dictationShortcut"
    private static let inputDeviceKey = "selectedInputDeviceID"

    var writingStyle: WritingStyle {
        didSet {
            UserDefaults.standard.set(writingStyle.rawValue, forKey: Self.writingStyleKey)
        }
    }

    var dictationShortcut: DictationShortcut {
        didSet {
            if let data = try? JSONEncoder().encode(dictationShortcut) {
                UserDefaults.standard.set(data, forKey: Self.shortcutKey)
            }
        }
    }

    var selectedInputDeviceID: String {
        didSet {
            UserDefaults.standard.set(selectedInputDeviceID, forKey: Self.inputDeviceKey)
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.writingStyleKey),
           let style = WritingStyle(rawValue: raw) {
            writingStyle = style
        } else {
            writingStyle = .balanced
        }

        if let data = UserDefaults.standard.data(forKey: Self.shortcutKey),
           let shortcut = try? JSONDecoder().decode(DictationShortcut.self, from: data) {
            dictationShortcut = shortcut
        } else {
            dictationShortcut = .default
        }

        selectedInputDeviceID = UserDefaults.standard.string(forKey: Self.inputDeviceKey)
            ?? AudioInputDevice.systemDefaultID
    }
}
