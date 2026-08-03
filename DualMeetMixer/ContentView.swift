import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var viewModel: MixerViewModel
    @ObservedObject var preferences: Preferences
    @State private var health: MixerViewModel.HealthReport = MixerViewModel.HealthReport(
        blackHoleAInstalled: true, blackHoleBInstalled: true,
        samePIDWarning: false, noWindowsSelected: false)
    private let healthTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            ColorTheme.surface.ignoresSafeArea()
            VStack(spacing: 0) {
                if !health.blackHoleBInstalled {
                    StatusBanner(
                        icon: "exclamationmark.triangle.fill",
                        message: "BlackHole-B isn't installed. Run Scripts/install-blackhole-b.sh.",
                        actionTitle: "Open Script",
                        action: {
                            let scriptURL = URL(fileURLWithPath: "Scripts/install-blackhole-b.sh", relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
                            NSWorkspace.shared.activateFileViewerSelecting([scriptURL])
                        },
                        tint: .orange
                    )
                    .padding([.horizontal, .top], 12)
                }
                if case .micMixerError(let msg) = viewModel.audioStatus {
                    StatusBanner(
                        icon: "speaker.slash.fill",
                        message: msg,
                        actionTitle: nil, action: nil,
                        tint: .red
                    )
                    .padding([.horizontal, .top], 12)
                }
                if case .routerError(let msg) = viewModel.audioStatus {
                    StatusBanner(
                        icon: "waveform.slash",
                        message: "Audio routing failed: \(msg)",
                        actionTitle: nil, action: nil,
                        tint: .red
                    )
                    .padding([.horizontal, .top], 12)
                }
                if case .samePIDRefused = viewModel.audioStatus {
                    StatusBanner(
                        icon: "exclamationmark.octagon.fill",
                        message: "Audio routing paused — both windows are in the same process. Pick a window in a different browser or profile.",
                        actionTitle: nil, action: nil,
                        tint: .red
                    )
                    .padding([.horizontal, .top], 12)
                }
                HStack(spacing: 0) {
                    MeetingPaneView(
                        viewModel: viewModel, side: .a,
                        controller: viewModel.controllerA,
                        label: preferences.labelA, cupSide: "L cup",
                        tint: ColorTheme.purpleA, audioRouting: "L ONLY"
                    )
                    Divider().background(Color.white.opacity(0.08))
                    GlobalControlView(
                        summary: viewModel.summary,
                        labelA: preferences.labelA,
                        labelB: preferences.labelB,
                        hotkeyADisplay: preferences.hotkeyA.displayString,
                        hotkeyBDisplay: preferences.hotkeyB.displayString,
                        onMuteAll: { viewModel.muteAll() },
                        muteAllEnabled: viewModel.controllerA.state.isTalking || viewModel.controllerB.state.isTalking
                    )
                    .frame(width: 240)
                    Divider().background(Color.white.opacity(0.08))
                    MeetingPaneView(
                        viewModel: viewModel, side: .b,
                        controller: viewModel.controllerB,
                        label: preferences.labelB, cupSide: "R cup",
                        tint: ColorTheme.redB, audioRouting: "R ONLY"
                    )
                }
            }
        }
        .frame(minWidth: 1024, minHeight: 600)
        .onReceive(healthTimer) { _ in
            health = viewModel.currentHealth()
        }
        .onAppear { health = viewModel.currentHealth() }
    }
}
