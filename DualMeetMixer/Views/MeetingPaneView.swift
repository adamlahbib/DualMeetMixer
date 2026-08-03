import SwiftUI

struct MeetingPaneView: View {
    @ObservedObject var viewModel: MixerViewModel
    let side: Side
    @ObservedObject var controller: MeetingController
    let label: String
    let cupSide: String
    let tint: Color
    let audioRouting: String
    @State private var nowDisplay: Date = Date()
    private let displayTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                Text(cupSide)
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(ColorTheme.mutedText)
                Divider().background(Color.white.opacity(0.08))
            }

            WindowPickerSlot(
                selected: side == .a ? viewModel.windowA : viewModel.windowB,
                onPick: { viewModel.setWindow($0, for: side) }
            )

            TalkButton(tint: tint, isActive: controller.state.isTalking) {
                viewModel.tap(side)
            }
            CountdownRing(
                progress: progressForRing(),
                secondsRemaining: Int(ceil(controller.remainingSeconds(now: nowDisplay))),
                tint: tint,
                isActive: controller.state.isTalking
            )

            VStack(spacing: 4) {
                Text("Status: \(controller.state.isTalking ? "MIC LIVE" : "MUTED")")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(controller.state.isTalking ? tint : ColorTheme.mutedText)
                Text("Audio: \(audioRouting)")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.mutedText)
            }
            Spacer()
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(displayTimer) { now in nowDisplay = now }
    }

    private func progressForRing() -> Double {
        let remaining = controller.remainingSeconds(now: nowDisplay)
        let total = TimeInterval(controller.keepAliveSeconds)
        return total > 0 ? remaining / total : 0
    }
}

private struct WindowPickerSlot: View {
    let selected: BrowserWindow?
    let onPick: (BrowserWindow) -> Void
    @State private var showPopover = false
    @State private var windows: [BrowserWindow] = []

    var body: some View {
        HStack {
            Image(systemName: "globe")
                .foregroundStyle(.white.opacity(0.7))
            VStack(alignment: .leading, spacing: 2) {
                if let w = selected {
                    Text(w.appName).foregroundStyle(.white).lineLimit(1)
                    Text(w.title).font(.caption)
                        .foregroundStyle(ColorTheme.mutedText).lineLimit(1)
                } else {
                    Text("(no window selected)").foregroundStyle(ColorTheme.mutedText)
                }
            }
            Spacer()
            Button("Pick…") {
                windows = WindowEnumerator.browserWindows()
                showPopover.toggle()
            }
            .buttonStyle(.borderedProminent)
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                WindowPickerPopover(windows: windows) {
                    onPick($0)
                    showPopover = false
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
    }
}
