import CoreAudio
import Foundation

enum AggregateDeviceError: Error {
    case createFailed(OSStatus)
    case destroyFailed(OSStatus)
}

final class AggregateDevice {

    private(set) var id: AudioObjectID = 0
    let name: String
    let uid: String

    init(name: String, uid: String = UUID().uuidString) {
        self.name = name
        self.uid = uid
    }

    struct SubDeviceSpec {
        let uid: String
        let driftCompensation: Bool
        init(uid: String, driftCompensation: Bool = false) {
            self.uid = uid
            self.driftCompensation = driftCompensation
        }
    }

    /// Build aggregate from sub-devices and process taps.
    /// `subDeviceUIDs`: list of regular audio device UIDs (e.g., BlackHole-A, BlackHole-B).
    /// `tapUUIDs`: list of process tap UUID strings.
    func create(subDeviceUIDs: [String] = [],
                tapUUIDs: [String] = [],
                isPrivate: Bool = true) throws {
        try create(subDevices: subDeviceUIDs.map { SubDeviceSpec(uid: $0) },
                   masterSubDeviceUID: nil,
                   tapUUIDs: tapUUIDs,
                   isPrivate: isPrivate)
    }

    /// Build aggregate with per-sub-device drift compensation and an optional master clock device.
    /// Use this when sub-devices have independent clocks (e.g., a USB headset + a virtual loopback)
    /// that would otherwise drift relative to each other and cause sample drops/duplications.
    func create(subDevices: [SubDeviceSpec],
                masterSubDeviceUID: String? = nil,
                tapUUIDs: [String] = [],
                isPrivate: Bool = true) throws {
        let subDeviceList: [[String: Any]] = subDevices.map { spec in
            var dict: [String: Any] = [kAudioSubDeviceUIDKey as String: spec.uid]
            if spec.driftCompensation {
                dict[kAudioSubDeviceDriftCompensationKey as String] = 1
            }
            return dict
        }
        let tapsList: [[String: Any]] = tapUUIDs.map { tapUID in
            [
                kAudioSubTapUIDKey as String: tapUID,
                kAudioSubTapDriftCompensationKey as String: 1
            ]
        }

        var description: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: name,
            kAudioAggregateDeviceUIDKey as String: uid,
            kAudioAggregateDeviceIsPrivateKey as String: isPrivate ? 1 : 0,
            kAudioAggregateDeviceIsStackedKey as String: 0
        ]
        if !subDeviceList.isEmpty {
            description[kAudioAggregateDeviceSubDeviceListKey as String] = subDeviceList
        }
        if let masterSubDeviceUID {
            description[kAudioAggregateDeviceMainSubDeviceKey as String] = masterSubDeviceUID
        }
        if !tapsList.isEmpty {
            description[kAudioAggregateDeviceTapListKey as String] = tapsList
        }

        var newID: AudioObjectID = 0
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &newID)
        guard status == noErr else {
            throw AggregateDeviceError.createFailed(status)
        }
        self.id = newID
    }

    func destroy() throws {
        guard id != 0 else { return }
        let status = AudioHardwareDestroyAggregateDevice(id)
        guard status == noErr else {
            throw AggregateDeviceError.destroyFailed(status)
        }
        id = 0
    }

    deinit {
        try? destroy()
    }
}
