import SwiftUI
import AppKit
import Carbon.HIToolbox

struct KeyRecorder: View {
    @Binding var hotKey: HotKey
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            HStack(spacing: 6) {
                Text(recording ? "Press a key…" : hotKey.displayString)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(recording ? 0.18 : 0.07)))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .onDisappear { stopRecording() }
    }

    private func toggleRecording() {
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Require at least one modifier so users don't accidentally bind a bare key.
            let nsMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let carbon = Self.carbonModifiers(from: nsMods)
            guard carbon != 0 else { return event }
            let newHotKey = HotKey(keyCode: UInt32(event.keyCode), modifiers: carbon)
            hotKey = newHotKey
            stopRecording()
            return nil  // consume the event so it doesn't propagate
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        recording = false
    }

    private static func carbonModifiers(from nsFlags: NSEvent.ModifierFlags) -> UInt32 {
        var m: Int = 0
        if nsFlags.contains(.control) { m |= controlKey }
        if nsFlags.contains(.option)  { m |= optionKey }
        if nsFlags.contains(.shift)   { m |= shiftKey }
        if nsFlags.contains(.command) { m |= cmdKey }
        return UInt32(m)
    }
}
