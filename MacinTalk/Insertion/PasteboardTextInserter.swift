import AppKit
import CoreGraphics
import Foundation

struct PasteboardSnapshot: Equatable {
    let changeCount: Int
    let items: [[String: Data]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items: [[String: Data]] = pasteboard.pasteboardItems?.map { item in
            var payload: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    payload[type.rawValue] = data
                }
            }
            return payload
        } ?? []

        return PasteboardSnapshot(changeCount: pasteboard.changeCount, items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }

        let restoredItems = items.map { payload -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (typeRaw, data) in payload {
                item.setData(data, forType: NSPasteboard.PasteboardType(typeRaw))
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }
}

final class PasteboardTextInserter: TextInserting {
    private let pasteDelay: TimeInterval = 0.05

    func insert(_ text: String, activating application: NSRunningApplication?) throws {
        guard CGPreflightPostEventAccess() || CGRequestPostEventAccess() else {
            throw TextInsertionError.postEventAccessDenied
        }

        application?.activate(options: [.activateIgnoringOtherApps])
        Thread.sleep(forTimeInterval: pasteDelay)

        try writeToClipboard(text)

        Thread.sleep(forTimeInterval: pasteDelay)
        try simulateCommandV()
    }

    func copyToClipboard(_ text: String) throws {
        try writeToClipboard(text)
    }

    private func writeToClipboard(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        guard pasteboard.setString(text, forType: .string) else {
            throw TextInsertionError.clipboardCopyFailed
        }
    }

    private func simulateCommandV() throws {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.01)
        keyUp?.post(tap: .cghidEventTap)
    }
}

enum ClipboardRetentionPolicy {
    static func retainsInsertedTextAfterPaste() -> Bool {
        true
    }
}
