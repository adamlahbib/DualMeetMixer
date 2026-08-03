import CoreAudio
import Foundation

enum DeviceUtils {

    static func allDeviceIDs() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr else {
            return []
        }
        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids) == noErr else {
            return []
        }
        return ids
    }

    static func name(of deviceID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name) == noErr else {
            return nil
        }
        return name as String
    }

    static func uid(of deviceID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid) == noErr else {
            return nil
        }
        return uid as String
    }

    static func find(byName name: String) -> AudioObjectID? {
        for id in allDeviceIDs() where DeviceUtils.name(of: id) == name {
            return id
        }
        return nil
    }

    static func find(byNameContaining substring: String) -> AudioObjectID? {
        for id in allDeviceIDs() {
            if let n = DeviceUtils.name(of: id), n.localizedCaseInsensitiveContains(substring) {
                return id
            }
        }
        return nil
    }

    /// Returns AudioObjectIDs of devices that have at least one input stream.
    static func inputDeviceIDs() -> [AudioObjectID] {
        return allDeviceIDs().filter { hasInputStreams($0) }
    }

    private static func hasInputStreams(_ deviceID: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr else { return false }
        return size > 0
    }

    static func find(byUID uid: String) -> AudioObjectID? {
        for id in allDeviceIDs() where DeviceUtils.uid(of: id) == uid {
            return id
        }
        return nil
    }

    static func defaultInputDevice() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr else {
            return nil
        }
        return id
    }

    static func defaultOutputDevice() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr else {
            return nil
        }
        return id
    }

    /// Total channel count across all streams on a given scope (input or output).
    static func channelCount(of deviceID: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        var streamsAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &streamsAddr, 0, nil, &size) == noErr else { return 0 }
        let count = Int(size) / MemoryLayout<AudioStreamID>.size
        guard count > 0 else { return 0 }
        var streams = [AudioStreamID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(deviceID, &streamsAddr, 0, nil, &size, &streams) == noErr else { return 0 }

        var total = 0
        var fmtAddr = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyVirtualFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        for stream in streams {
            var fmt = AudioStreamBasicDescription()
            var fmtSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            if AudioObjectGetPropertyData(stream, &fmtAddr, 0, nil, &fmtSize, &fmt) == noErr {
                total += Int(fmt.mChannelsPerFrame)
            }
        }
        return total
    }
}

struct BlackHoleDevices {
    let a: AudioObjectID?
    let b: AudioObjectID?

    var bothInstalled: Bool { a != nil && b != nil }

    static func detect() -> BlackHoleDevices {
        let a = DeviceUtils.find(byName: "BlackHole-A")
                ?? DeviceUtils.find(byName: "BlackHole 2ch")
        let b = DeviceUtils.find(byName: "BlackHole-B")
        return BlackHoleDevices(a: a, b: b)
    }
}

struct AudioInputDevice: Identifiable, Hashable {
    let id: AudioObjectID
    let uid: String
    let name: String

    static func enumerate() -> [AudioInputDevice] {
        DeviceUtils.inputDeviceIDs().compactMap { id -> AudioInputDevice? in
            guard let uid = DeviceUtils.uid(of: id),
                  let name = DeviceUtils.name(of: id) else { return nil }
            return AudioInputDevice(id: id, uid: uid, name: name)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
