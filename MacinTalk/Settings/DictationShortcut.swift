import AppKit
import CoreGraphics
import Foundation

struct DictationShortcut: Codable, Equatable, Sendable {
    var keyCode: UInt16 = 49
    var usesControl = true
    var usesOption = true
    var usesCommand = false
    var usesShift = false

    static let `default` = DictationShortcut()

    var displayString: String {
        var parts: [String] = []
        if usesControl { parts.append("⌃") }
        if usesOption { parts.append("⌥") }
        if usesShift { parts.append("⇧") }
        if usesCommand { parts.append("⌘") }
        parts.append(Self.keyDisplayName(for: keyCode))
        return parts.joined()
    }

    var promptMessage: String {
        "Hold \(displayString) to dictate"
    }

    func matches(event: CGEvent) -> Bool {
        let flags = event.flags
        guard flags.contains(.maskControl) == usesControl else { return false }
        guard flags.contains(.maskAlternate) == usesOption else { return false }
        guard flags.contains(.maskShift) == usesShift else { return false }
        guard flags.contains(.maskCommand) == usesCommand else { return false }

        let eventKeyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        return eventKeyCode == keyCode
    }

    static func from(event: NSEvent) -> DictationShortcut? {
        let keyCode = UInt16(event.keyCode)
        guard keyCode != 0 else { return nil }

        let flags = event.modifierFlags
        let usesControl = flags.contains(.control)
        let usesOption = flags.contains(.option)
        let usesCommand = flags.contains(.command)
        let usesShift = flags.contains(.shift)

        guard usesControl || usesOption || usesCommand || usesShift else { return nil }

        return DictationShortcut(
            keyCode: keyCode,
            usesControl: usesControl,
            usesOption: usesOption,
            usesCommand: usesCommand,
            usesShift: usesShift
        )
    }

    static func keyDisplayName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 53: return "Escape"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            if let scalar = keyCodeToUnicodeScalar(keyCode) {
                return String(Character(scalar)).uppercased()
            }
            return "Key \(keyCode)"
        }
    }

    private static func keyCodeToUnicodeScalar(_ keyCode: UInt16) -> UnicodeScalar? {
        let mapping: [UInt16: UInt32] = [
            0: 0x41, 1: 0x53, 2: 0x44, 3: 0x46, 4: 0x48, 5: 0x47, 6: 0x5A, 7: 0x58,
            8: 0x43, 9: 0x56, 11: 0x42, 12: 0x51, 13: 0x57, 14: 0x45, 15: 0x52, 16: 0x59,
            17: 0x54, 31: 0x4F, 32: 0x55, 34: 0x49, 35: 0x50, 37: 0x4C, 38: 0x4A, 40: 0x4B,
            45: 0x4E, 46: 0x4D
        ]
        guard let scalarValue = mapping[keyCode], let scalar = UnicodeScalar(scalarValue) else {
            return nil
        }
        return scalar
    }
}
