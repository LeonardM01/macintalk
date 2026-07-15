import AVFoundation
import Foundation

struct AudioInputDevice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String

    static let systemDefaultID = ""

    static var systemDefault: AudioInputDevice {
        AudioInputDevice(id: systemDefaultID, name: "System Default")
    }
}

enum AudioInputDeviceDiscovery {
    static func availableDevices() -> [AudioInputDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        let devices = discoverySession.devices.map { device in
            AudioInputDevice(id: device.uniqueID, name: device.localizedName)
        }

        return [AudioInputDevice.systemDefault] + devices
    }

    static func captureDevice(for deviceID: String?) -> AVCaptureDevice? {
        guard let deviceID, !deviceID.isEmpty else {
            return AVCaptureDevice.default(for: .audio)
        }

        if let device = AVCaptureDevice(uniqueID: deviceID) {
            return device
        }

        return AVCaptureDevice.default(for: .audio)
    }
}
