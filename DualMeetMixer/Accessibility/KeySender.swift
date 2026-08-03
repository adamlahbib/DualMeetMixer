import Carbon.HIToolbox
import AppKit

enum KeySender {

    /// Send a `Cmd+D` to the application that owns the given window.
    /// Returns true if the event was posted; does not guarantee Meet acted on it.
    @discardableResult
    static func sendCmdD(toPID pid: pid_t) -> Bool {
        return sendKey(keyCode: CGKeyCode(kVK_ANSI_D), toPID: pid)
    }

    /// Send a `Cmd+E` to the application that owns the given window.
    /// Returns true if the event was posted; does not guarantee Meet acted on it.
    @discardableResult
    static func sendCmdE(toPID pid: pid_t) -> Bool {
        return sendKey(keyCode: CGKeyCode(kVK_ANSI_E), toPID: pid)
    }

    private static func sendKey(keyCode: CGKeyCode, toPID pid: pid_t) -> Bool {
        guard AXIsProcessTrusted() else {
            print("[KeySender] Accessibility permission not granted")
            return false
        }
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.postToPid(pid)
        up?.postToPid(pid)
        return down != nil && up != nil
    }
}
