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
        guard pasteboard.changeCount == changeCount + 1 || pasteboard.changeCount == changeCount else {
            return
        }

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
    func insert(_ text: String) throws {
        guard CGPreflightPostEventAccess() || CGRequestPostEventAccess() else {
            throw TextInsertionError.postEventAccessDenied
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw TextInsertionError.pasteFailed
        }

        try simulateCommandV()

        if pasteboard.string(forType: .string) == text {
            snapshot.restore(to: pasteboard)
        }
    }

    private func simulateCommandV() throws {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

enum PasteboardRestorePolicy {
    static func shouldRestore(snapshot: PasteboardSnapshot, currentChangeCount: Int, insertedText: String, currentText: String?) -> Bool {
        currentText == insertedText
    }
}
