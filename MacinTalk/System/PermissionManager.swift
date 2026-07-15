import AVFoundation
import AppKit
import CoreGraphics
import Foundation

final class PermissionManager: PermissionChecking {
    private let preferredLocale: Locale

    init(preferredLocale: Locale = .current) {
        self.preferredLocale = preferredLocale
    }

    func readinessSnapshot() async -> PermissionReadiness {
        let resolution = await SpeechLocaleResolver.resolve(preferred: preferredLocale)
        let assetsInstalled = await SpeechReadinessChecker.assetsInstalled(for: resolution.locale)

        return PermissionReadiness(
            microphoneGranted: microphoneGranted(),
            inputMonitoringGranted: CGPreflightListenEventAccess(),
            postEventGranted: CGPreflightPostEventAccess(),
            speechLocaleSupported: true,
            speechAssetsInstalled: assetsInstalled,
            appleIntelligenceAvailable: AppleIntelligenceReadiness.isAvailable,
            speechLocaleLabel: resolution.displayName,
            speechLocaleUsesFallback: resolution.isUsingFallback,
            preferredLocaleLabel: resolution.preferredLocale.identifier(.bcp47)
        )
    }

    func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            openMicrophoneSettings()
            return false
        }
    }

    func requestInputMonitoringAccess() -> Bool {
        if CGPreflightListenEventAccess() {
            return true
        }
        _ = CGRequestListenEventAccess()
        openInputMonitoringSettings()
        return CGPreflightListenEventAccess()
    }

    func requestPostEventAccess() -> Bool {
        if CGPreflightPostEventAccess() {
            return true
        }
        _ = CGRequestPostEventAccess()
        openAccessibilitySettings()
        return CGPreflightPostEventAccess()
    }

    private func microphoneGranted() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
