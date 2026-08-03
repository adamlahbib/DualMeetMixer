import Carbon.HIToolbox
import Foundation

struct HotKey: Equatable, Hashable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let leftArrow = HotKey(
        keyCode: UInt32(kVK_LeftArrow),
        modifiers: UInt32(controlKey | optionKey | cmdKey)
    )
    static let rightArrow = HotKey(
        keyCode: UInt32(kVK_RightArrow),
        modifiers: UInt32(controlKey | optionKey | cmdKey)
    )
    static let downArrow = HotKey(
        keyCode: UInt32(kVK_DownArrow),
        modifiers: UInt32(controlKey | optionKey | cmdKey)
    )
}

extension HotKey {
    var displayString: String {
        var parts: [String] = []
        let m = Int(modifiers)
        if m & controlKey != 0  { parts.append("⌃") }
        if m & optionKey != 0   { parts.append("⌥") }
        if m & shiftKey != 0    { parts.append("⇧") }
        if m & cmdKey != 0      { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined(separator: " ")
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_LeftArrow:        return "←"
        case kVK_RightArrow:       return "→"
        case kVK_UpArrow:          return "↑"
        case kVK_DownArrow:        return "↓"
        case kVK_Space:            return "Space"
        case kVK_Return:           return "↩"
        case kVK_Tab:              return "⇥"
        case kVK_Escape:           return "⎋"
        case kVK_Delete:           return "⌫"
        case kVK_F1:               return "F1"
        case kVK_F2:               return "F2"
        case kVK_F3:               return "F3"
        case kVK_F4:               return "F4"
        case kVK_F5:               return "F5"
        case kVK_F6:               return "F6"
        case kVK_F7:               return "F7"
        case kVK_F8:               return "F8"
        case kVK_F9:               return "F9"
        case kVK_F10:              return "F10"
        case kVK_F11:              return "F11"
        case kVK_F12:              return "F12"
        default:
            // ANSI letters / numbers
            let map: [Int: String] = [
                kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
                kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
                kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
                kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
                kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
                kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
                kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
                kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
                kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
                kVK_ANSI_8: "8", kVK_ANSI_9: "9"
            ]
            return map[Int(keyCode)] ?? "?"
        }
    }
}
