import CoreAudio
import Foundation
import Darwin

@available(macOS 14.2, *)
final class ProcessTap {

    let pid: pid_t
    private(set) var tapID: AudioObjectID = 0
    private(set) var description: CATapDescription?

    init(pid: pid_t) {
        self.pid = pid
    }

    func create() throws {
        let processObjectIDs = try Self.collectAudioProcessObjects(rootPID: pid)
        DMMLog.log("[ProcessTap] pid=\(pid) tapping \(processObjectIDs.count) audio process object(s): \(processObjectIDs)")
        let desc = CATapDescription(stereoMixdownOfProcesses: processObjectIDs)
        desc.muteBehavior = .mutedWhenTapped
        desc.isPrivate = true
        var newTapID: AudioObjectID = 0
        let status = AudioHardwareCreateProcessTap(desc, &newTapID)
        guard status == noErr else {
            throw NSError(domain: "ProcessTap",
                          code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "AudioHardwareCreateProcessTap failed (\(status))"])
        }
        DMMLog.log("[ProcessTap] created tap=\(newTapID) for pid=\(pid) processObjectIDs=\(processObjectIDs) uuid=\(desc.uuid.uuidString)")
        self.tapID = newTapID
        self.description = desc
    }

    /// Collect all CoreAudio process objects in the process subtree rooted at rootPID.
    /// Browsers split work across helper/renderer/WebContent child processes, and the audio
    /// may be produced by any of them. Tapping the union covers all cases.
    private static func collectAudioProcessObjects(rootPID: pid_t) throws -> [AudioObjectID] {
        var results: [AudioObjectID] = []
        var seenPIDs = Set<pid_t>()
        if let direct = directTranslate(rootPID), direct != 0 {
            results.append(direct)
            seenPIDs.insert(rootPID)
        }
        for (pid, objectID) in allAudioProcessesInSubtree(rootPID: rootPID) where !seenPIDs.contains(pid) {
            results.append(objectID)
            seenPIDs.insert(pid)
        }
        guard !results.isEmpty else {
            throw NSError(domain: "ProcessTap",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "No CoreAudio process object found for pid \(rootPID) or any of its descendants. The window may have no active audio (try playing audio in it first)."])
        }
        return results
    }

    private static func directTranslate(_ pid: pid_t) -> AudioObjectID? {
        var inputPID = pid
        var processObjectID: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            UInt32(MemoryLayout<pid_t>.size),
            &inputPID,
            &size,
            &processObjectID
        )
        return (status == noErr && processObjectID != 0) ? processObjectID : nil
    }

    /// Returns all (pid, audioObjectID) pairs whose pid is a descendant of rootPID.
    private static func allAudioProcessesInSubtree(rootPID: pid_t) -> [(pid: pid_t, objectID: AudioObjectID)] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return [] }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        guard count > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return [] }

        var pidAddr = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var matches: [(pid_t, AudioObjectID)] = []
        for objectID in ids {
            var pid: pid_t = 0
            var psize = UInt32(MemoryLayout<pid_t>.size)
            guard AudioObjectGetPropertyData(objectID, &pidAddr, 0, nil, &psize, &pid) == noErr else { continue }
            if pid > 0 && pid != rootPID && isDescendant(pid: pid, of: rootPID) {
                matches.append((pid, objectID))
            }
        }
        return matches
    }

    private static func isDescendant(pid: pid_t, of ancestor: pid_t) -> Bool {
        var current = pid
        for _ in 0..<8 {
            guard let parent = parentPID(of: current), parent > 0, parent != current else { return false }
            if parent == ancestor { return true }
            current = parent
        }
        return false
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size))
        guard result == size else { return nil }
        return pid_t(info.pbi_ppid)
    }

    func destroy() {
        guard tapID != 0 else { return }
        AudioHardwareDestroyProcessTap(tapID)
        tapID = 0
        description = nil
    }

    deinit { destroy() }

    func uid() -> String? {
        guard let desc = description else { return nil }
        return desc.uuid.uuidString
    }
}
