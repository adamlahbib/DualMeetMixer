import SwiftUI

struct GlobalControlView: View {
    let summary: String
    let labelA: String
    let labelB: String
    let hotkeyADisplay: String
    let hotkeyBDisplay: String
    let onMuteAll: () -> Void
    var muteAllEnabled: Bool

    var body: some View {
        VStack(spacing: 18) {
            Text("GLOBAL CONTROL")
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.mutedText)
                .tracking(2)

            MuteAllButton(action: onMuteAll, enabled: muteAllEnabled)

            VStack(spacing: 8) {
                ShortcutRow(combo: hotkeyADisplay, description: "unmute \(labelA)")
                ShortcutRow(combo: hotkeyBDisplay, description: "unmute \(labelB)")
            }

            Text(summary)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.06)))
        }
    }
}

private struct MuteAllButton: View {
    let action: () -> Void
    let enabled: Bool

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(enabled ? 0.10 : 0.04))
                    .frame(width: 64, height: 64)
                Circle()
                    .stroke(Color.white.opacity(enabled ? 0.30 : 0.10), lineWidth: 1)
                    .frame(width: 64, height: 64)
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(enabled ? 1 : 0.35))
            }
        }
        .buttonStyle(.plain)
        .help(enabled ? "Mute both meetings" : "Both meetings already muted")
        .disabled(!enabled)
    }
}

private struct ShortcutRow: View {
    let combo: String
    let description: String
    var body: some View {
        HStack(spacing: 8) {
            Text(combo)
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.07)))
            Text(description)
                .font(.caption)
                .foregroundStyle(ColorTheme.mutedText)
        }
        .foregroundStyle(.white)
    }
}
