import Foundation
import SwiftUI

final class Preferences: ObservableObject {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self._labelA = defaults.string(forKey: Key.labelA) ?? "Window A"
        self._labelB = defaults.string(forKey: Key.labelB) ?? "Window B"
        self.keepAliveSeconds = max(10, defaults.object(forKey: Key.keepAliveSeconds) as? Int ?? 10)
        self.cmdDBeltAndSuspenders = defaults.bool(forKey: Key.cmdDBeltAndSuspenders)
        self.useCmdDForMicMute = defaults.bool(forKey: Key.useCmdDForMicMute)
        self.cameraFollowsTalker = defaults.bool(forKey: Key.cameraFollowsTalker)
        self.inputDeviceUID = defaults.string(forKey: Key.inputDeviceUID)

        let aCode = (defaults.object(forKey: Key.hotkeyAKeyCode) as? Int).map { UInt32($0) } ?? HotKey.leftArrow.keyCode
        let aMods = (defaults.object(forKey: Key.hotkeyAModifiers) as? Int).map { UInt32($0) } ?? HotKey.leftArrow.modifiers
        self.hotkeyA = HotKey(keyCode: aCode, modifiers: aMods)
        let bCode = (defaults.object(forKey: Key.hotkeyBKeyCode) as? Int).map { UInt32($0) } ?? HotKey.rightArrow.keyCode
        let bMods = (defaults.object(forKey: Key.hotkeyBModifiers) as? Int).map { UInt32($0) } ?? HotKey.rightArrow.modifiers
        self.hotkeyB = HotKey(keyCode: bCode, modifiers: bMods)
        let mCode = (defaults.object(forKey: Key.hotkeyMuteAllKeyCode) as? Int).map { UInt32($0) } ?? HotKey.downArrow.keyCode
        let mMods = (defaults.object(forKey: Key.hotkeyMuteAllModifiers) as? Int).map { UInt32($0) } ?? HotKey.downArrow.modifiers
        self.hotkeyMuteAll = HotKey(keyCode: mCode, modifiers: mMods)
    }

    private enum Key {
        static let labelA = "labelA"
        static let labelB = "labelB"
        static let keepAliveSeconds = "keepAliveSeconds"
        static let cmdDBeltAndSuspenders = "cmdDBeltAndSuspenders"
        static let useCmdDForMicMute = "useCmdDForMicMute"
        static let cameraFollowsTalker = "cameraFollowsTalker"
        static let inputDeviceUID = "inputDeviceUID"
        static let lastWindowAPID = "lastWindowAPID"
        static let lastWindowBPID = "lastWindowBPID"
        static let hotkeyAKeyCode = "hotkeyAKeyCode"
        static let hotkeyAModifiers = "hotkeyAModifiers"
        static let hotkeyBKeyCode = "hotkeyBKeyCode"
        static let hotkeyBModifiers = "hotkeyBModifiers"
        static let hotkeyMuteAllKeyCode = "hotkeyMuteAllKeyCode"
        static let hotkeyMuteAllModifiers = "hotkeyMuteAllModifiers"
    }

    @Published private var _labelA: String
    var labelA: String {
        get { _labelA.isEmpty ? "Window A" : _labelA }
        set {
            _labelA = newValue
            defaults.set(newValue, forKey: Key.labelA)
        }
    }

    @Published private var _labelB: String
    var labelB: String {
        get { _labelB.isEmpty ? "Window B" : _labelB }
        set {
            _labelB = newValue
            defaults.set(newValue, forKey: Key.labelB)
        }
    }

    @Published var keepAliveSeconds: Int {
        didSet { defaults.set(keepAliveSeconds, forKey: Key.keepAliveSeconds) }
    }

    @Published var cmdDBeltAndSuspenders: Bool {
        didSet { defaults.set(cmdDBeltAndSuspenders, forKey: Key.cmdDBeltAndSuspenders) }
    }

    @Published var useCmdDForMicMute: Bool {
        didSet { defaults.set(useCmdDForMicMute, forKey: Key.useCmdDForMicMute) }
    }

    @Published var cameraFollowsTalker: Bool {
        didSet { defaults.set(cameraFollowsTalker, forKey: Key.cameraFollowsTalker) }
    }

    @Published var inputDeviceUID: String? {
        didSet {
            if let uid = inputDeviceUID {
                defaults.set(uid, forKey: Key.inputDeviceUID)
            } else {
                defaults.removeObject(forKey: Key.inputDeviceUID)
            }
        }
    }

    @Published var hotkeyA: HotKey {
        didSet {
            defaults.set(Int(hotkeyA.keyCode), forKey: Key.hotkeyAKeyCode)
            defaults.set(Int(hotkeyA.modifiers), forKey: Key.hotkeyAModifiers)
        }
    }

    @Published var hotkeyB: HotKey {
        didSet {
            defaults.set(Int(hotkeyB.keyCode), forKey: Key.hotkeyBKeyCode)
            defaults.set(Int(hotkeyB.modifiers), forKey: Key.hotkeyBModifiers)
        }
    }

    @Published var hotkeyMuteAll: HotKey {
        didSet {
            defaults.set(Int(hotkeyMuteAll.keyCode), forKey: Key.hotkeyMuteAllKeyCode)
            defaults.set(Int(hotkeyMuteAll.modifiers), forKey: Key.hotkeyMuteAllModifiers)
        }
    }

    var lastWindowAPID: Int? {
        get { defaults.object(forKey: Key.lastWindowAPID) as? Int }
        set { defaults.set(newValue, forKey: Key.lastWindowAPID) }
    }

    var lastWindowBPID: Int? {
        get { defaults.object(forKey: Key.lastWindowBPID) as? Int }
        set { defaults.set(newValue, forKey: Key.lastWindowBPID) }
    }

    static let shared = Preferences()
}
