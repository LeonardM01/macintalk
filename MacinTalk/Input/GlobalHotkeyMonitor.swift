import AppKit
import CoreGraphics
import Foundation

final class GlobalHotkeyMonitor: HotkeyMonitoring, @unchecked Sendable {
    var onHotkeyPressed: (() -> Void)?
    var onHotkeyReleased: (() -> Void)?

    private let stateLock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHotkeyHeld = false
    private var shortcut = DictationShortcut.default

    func configure(shortcut: DictationShortcut) {
        stateLock.lock()
        self.shortcut = shortcut
        stateLock.unlock()
    }

    func start() throws {
        guard CGPreflightListenEventAccess() || CGRequestListenEventAccess() else {
            throw DictationFailure.inputMonitoringDenied
        }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }
            let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handleEvent(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw DictationFailure.inputMonitoringDenied
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        stateLock.lock()
        isHotkeyHeld = false
        stateLock.unlock()
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        stateLock.lock()
        let shortcut = self.shortcut
        stateLock.unlock()

        guard shortcut.matches(event: event) else {
            if type == .keyUp {
                dispatchReleaseIfHeld()
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            guard !isRepeat else {
                return nil
            }

            stateLock.lock()
            let shouldStart = !isHotkeyHeld
            if shouldStart {
                isHotkeyHeld = true
            }
            let handler = onHotkeyPressed
            stateLock.unlock()

            if shouldStart {
                dispatchOnMain(handler)
            }
        } else if type == .keyUp {
            dispatchReleaseIfHeld()
        }

        return nil
    }

    private func dispatchReleaseIfHeld() {
        stateLock.lock()
        guard isHotkeyHeld else {
            stateLock.unlock()
            return
        }
        isHotkeyHeld = false
        let handler = onHotkeyReleased
        stateLock.unlock()
        dispatchOnMain(handler)
    }

    private func dispatchOnMain(_ handler: (() -> Void)?) {
        guard let handler else { return }
        DispatchQueue.main.async(execute: handler)
    }
}

enum HotkeyEdgeHandler {
    static func shouldStart(isIdle: Bool, isRepeat: Bool, alreadyHeld: Bool) -> Bool {
        isIdle && !isRepeat && !alreadyHeld
    }

    static func shouldStop(isRecording: Bool, isHeld: Bool) -> Bool {
        isRecording && isHeld
    }
}
