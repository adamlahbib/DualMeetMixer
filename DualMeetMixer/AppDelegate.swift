import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var menuBar: MenuBarController?
    private var hotkeys: HotKeyService?
    private var preferenceCancellables: Set<AnyCancellable> = []
    let viewModel = MixerViewModel(keepAliveSeconds: Preferences.shared.keepAliveSeconds,
                                   preferences: .shared)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestPermissions()
        viewModel.startTicking()
        viewModel.startAudio()
        viewModel.restoreLastWindows()

        rebindHotkeys()
        let prefs = Preferences.shared
        prefs.$hotkeyA.dropFirst().sink { [weak self] _ in
            self?.rebindHotkeys()
        }.store(in: &preferenceCancellables)
        prefs.$hotkeyB.dropFirst().sink { [weak self] _ in
            self?.rebindHotkeys()
        }.store(in: &preferenceCancellables)
        prefs.$hotkeyMuteAll.dropFirst().sink { [weak self] _ in
            self?.rebindHotkeys()
        }.store(in: &preferenceCancellables)

        menuBar = MenuBarController(appDelegate: self, viewModel: viewModel, preferences: .shared)
        showMainWindow()
    }

    /// Request the OS permissions DMM needs:
    /// - Microphone: required to read from the user's mic and feed BlackHole virtual devices.
    /// - Screen Recording: required for CoreAudio process taps to capture audio from other apps
    ///   on macOS 14.x. Without it the taps may be created but produce silence and the
    ///   `mutedWhenTapped` behavior won't apply, so per-window L/R routing won't work.
    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DMMLog.log("[permissions] microphone granted=\(granted)")
        }
        // Triggers the Screen Recording prompt the first time it returns false.
        let hasScreenCapture = CGPreflightScreenCaptureAccess()
        DMMLog.log("[permissions] screen capture preflight=\(hasScreenCapture)")
        if !hasScreenCapture {
            let requested = CGRequestScreenCaptureAccess()
            DMMLog.log("[permissions] screen capture request returned \(requested)")
        }
    }

    private func rebindHotkeys() {
        let hk = HotKeyService()
        hk.register(Preferences.shared.hotkeyA) { [weak self] in self?.viewModel.tap(.a) }
        hk.register(Preferences.shared.hotkeyB) { [weak self] in self?.viewModel.tap(.b) }
        hk.register(Preferences.shared.hotkeyMuteAll) { [weak self] in self?.viewModel.muteAll() }
        self.hotkeys = hk    // replacing the old service deregisters via deinit
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func showMainWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = ContentView(viewModel: viewModel, preferences: .shared)
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Dual Meet Mixer"
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.setContentSize(NSSize(width: 1024, height: 600))
        win.center()
        // Prevent NSWindow's legacy auto-release-on-close so reopen via menu bar
        // doesn't crash on a freed window.
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }
}
