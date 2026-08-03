import AppKit
import Combine

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private(set) weak var appDelegate: AppDelegate?
    private var cancellables: Set<AnyCancellable> = []
    private var displayTimer: Timer?

    init(appDelegate: AppDelegate, viewModel: MixerViewModel, preferences: Preferences) {
        self.appDelegate = appDelegate
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureMenu()
        bind(viewModel: viewModel, preferences: preferences)
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Window", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Dual Meet Mixer", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    private func bind(viewModel: MixerViewModel, preferences: Preferences) {
        viewModel.objectWillChange.sink { [weak self, weak viewModel, weak preferences] in
            DispatchQueue.main.async {
                guard let vm = viewModel, let prefs = preferences else { return }
                self?.refreshIcon(vm: vm, prefs: prefs)
            }
        }.store(in: &cancellables)

        // Tooltip refresh ticks the countdown
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self, weak viewModel, weak preferences] _ in
            guard let vm = viewModel, let prefs = preferences else { return }
            self?.refreshIcon(vm: vm, prefs: prefs)
        }

        // Initial render
        refreshIcon(vm: viewModel, prefs: preferences)
    }

    private func refreshIcon(vm: MixerViewModel, prefs: Preferences) {
        guard let button = statusItem.button else { return }
        let now = Date()

        let symbol: String
        let tint: NSColor?
        let tooltip: String

        if vm.controllerA.state.isTalking {
            symbol = "mic.fill"
            tint = NSColor(red: 0.55, green: 0.27, blue: 0.95, alpha: 1)
            let s = Int(ceil(vm.controllerA.remainingSeconds(now: now)))
            tooltip = "Talking to \(prefs.labelA) · \(s)s"
        } else if vm.controllerB.state.isTalking {
            symbol = "mic.fill"
            tint = NSColor(red: 0.95, green: 0.27, blue: 0.27, alpha: 1)
            let s = Int(ceil(vm.controllerB.remainingSeconds(now: now)))
            tooltip = "Talking to \(prefs.labelB) · \(s)s"
        } else {
            symbol = "mic.slash"
            tint = nil
            tooltip = "Dual Meet Mixer · all muted"
        }

        // SF Symbol tinting via `contentTintColor` is unreliable for menu-bar
        // status items. Use an explicit palette SymbolConfiguration for the
        // colored states; keep the muted state as a template image so it
        // adapts to dark/light menu bar.
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        if let color = tint {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
            let colored = img?.withSymbolConfiguration(config)
            colored?.isTemplate = false
            button.image = colored
            button.contentTintColor = nil
        } else {
            img?.isTemplate = true
            button.image = img
            button.contentTintColor = nil
        }
        button.toolTip = tooltip
    }

    @objc private func showWindow() { appDelegate?.showMainWindow() }
    @objc private func showSettings() {
        if NSApp.activationPolicy() == .accessory {
            NSApp.activate(ignoringOtherApps: true)
        }
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
