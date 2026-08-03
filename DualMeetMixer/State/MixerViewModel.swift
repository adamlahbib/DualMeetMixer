import Foundation
import Combine
import AppKit

final class MixerViewModel: ObservableObject {

    enum AudioStatus: Equatable {
        case idle
        case running
        case micMixerError(String)      // e.g., BlackHole-A or B missing
        case routerError(String)
        case samePIDRefused
    }

    let controllerA: MeetingController
    let controllerB: MeetingController
    let preferences: Preferences
    let micMixer: MicMixer
    private let audioRouter: AudioRouter?
    private let clock: () -> Date
    private var cancellables: Set<AnyCancellable> = []
    private var stateObservers: Set<AnyCancellable> = []
    private var tickTimer: Timer?
    private var validationTimer: Timer?
    private var lastTalkingA = false
    private var lastTalkingB = false
    private var cameraOnA = false
    private var cameraOnB = false
    private var micUnmutedA = false
    private var micUnmutedB = false

    @Published var audioStatus: AudioStatus = .idle

    init(keepAliveSeconds: Int = 10,
         clock: @escaping () -> Date = Date.init,
         preferences: Preferences = .shared,
         micMixer: MicMixer = MicMixer(),
         audioRouter: AudioRouter? = nil) {
        self.controllerA = MeetingController(side: .a, keepAliveSeconds: keepAliveSeconds, clock: clock)
        self.controllerB = MeetingController(side: .b, keepAliveSeconds: keepAliveSeconds, clock: clock)
        self.preferences = preferences
        self.micMixer = micMixer
        if #available(macOS 14.2, *) {
            self.audioRouter = audioRouter ?? AudioRouter()
        } else {
            self.audioRouter = nil
        }
        self.clock = clock

        // Republish controller changes so views observing the VM get updates.
        controllerA.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        controllerB.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        // Mic control: two modes, chosen via Preferences.useCmdDForMicMute.
        //  - false (default): BlackHole gain mode — DMM controls audio reaching
        //    Meet by gating samples written to BlackHole-A / BlackHole-B.
        //    Meet should be configured with BlackHole-A / BlackHole-B as its mic.
        //  - true: Cmd+D mode — DMM keeps gain at 0 (no audio to BlackHole) and
        //    sends Cmd+D to toggle Meet's app-level mute, like camera-follows-
        //    talker uses Cmd+E. Meet should be configured with the real mic
        //    (e.g., Jabra) directly so audio bypasses DMM entirely and sounds
        //    natural to the other side.
        controllerA.$state.sink { [weak self] state in
            guard let self else { return }
            if self.useCmdDMode(for: .a) {
                self.micMixer.setGain(.a, 0)
                self.syncMic(side: .a, isTalking: state.isTalking)
            } else {
                self.micMixer.setGain(.a, state.isTalking ? 1 : 0)
            }
        }.store(in: &stateObservers)
        controllerB.$state.sink { [weak self] state in
            guard let self else { return }
            if self.useCmdDMode(for: .b) {
                self.micMixer.setGain(.b, 0)
                self.syncMic(side: .b, isTalking: state.isTalking)
            } else {
                self.micMixer.setGain(.b, state.isTalking ? 1 : 0)
            }
        }.store(in: &stateObservers)

        // Belt-and-suspenders: send Cmd+D on every state transition. Skipped
        // when Cmd+D mode is the primary mute mechanism (syncMic already
        // handles that with proper state tracking).
        controllerA.$state.sink { [weak self] state in
            guard let self else { return }
            if self.lastTalkingA != state.isTalking {
                if !self.preferences.useCmdDForMicMute,
                   self.preferences.cmdDBeltAndSuspenders,
                   let pid = self.windowA?.pid {
                    KeySender.sendCmdD(toPID: pid)
                }
                self.lastTalkingA = state.isTalking
            }
        }.store(in: &stateObservers)

        controllerB.$state.sink { [weak self] state in
            guard let self else { return }
            if self.lastTalkingB != state.isTalking {
                if !self.preferences.useCmdDForMicMute,
                   self.preferences.cmdDBeltAndSuspenders,
                   let pid = self.windowB?.pid {
                    KeySender.sendCmdD(toPID: pid)
                }
                self.lastTalkingB = state.isTalking
            }
        }.store(in: &stateObservers)

        // Camera follows the talker: send Cmd+E to toggle Meet's camera so the
        // active side's camera is on and the other side's camera is off.
        controllerA.$state.sink { [weak self] state in
            guard let self else { return }
            self.syncCamera(side: .a, isTalking: state.isTalking)
        }.store(in: &stateObservers)

        controllerB.$state.sink { [weak self] state in
            guard let self else { return }
            self.syncCamera(side: .b, isTalking: state.isTalking)
        }.store(in: &stateObservers)

        // Update audio router whenever window selection changes.
        Publishers.CombineLatest($windowA, $windowB).sink { [weak self] a, b in
            self?.refreshAudioRouting(a: a, b: b)
        }.store(in: &stateObservers)

        // Live-propagate keep-alive changes from Preferences to controllers.
        preferences.$keepAliveSeconds.sink { [weak self] newValue in
            self?.controllerA.updateKeepAlive(seconds: newValue)
            self?.controllerB.updateKeepAlive(seconds: newValue)
        }.store(in: &stateObservers)

        // Restart MicMixer whenever the input device pref changes.
        preferences.$inputDeviceUID.dropFirst().sink { [weak self] _ in
            self?.restartMicMixer()
        }.store(in: &stateObservers)
    }

    func tap(_ side: Side) {
        let other = side.opposite
        if controller(for: other).state.isTalking {
            controller(for: other).forceIdle()
        }
        controller(for: side).tap()
    }

    func muteAll() {
        if controllerA.state.isTalking { controllerA.forceIdle() }
        if controllerB.state.isTalking { controllerB.forceIdle() }
    }

    /// Re-sync DMM's belief about each side's camera to "off". Call this after
    /// manually turning both cameras off in Meet to recover from a toggle drift.
    func resetCameraState() {
        cameraOnA = false
        cameraOnB = false
    }

    /// Re-sync DMM's belief about each side's mic to "muted". Call this after
    /// manually muting both Meet windows (Cmd+D mode) to recover from a drift.
    func resetMicState() {
        micUnmutedA = false
        micUnmutedB = false
    }

    func tick() {
        controllerA.tick()
        controllerB.tick()
    }

    func startTicking(interval: TimeInterval = 0.05) {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        validationTimer?.invalidate()
        validationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.validateSelectedWindows()
        }
    }

    func stopTicking() {
        tickTimer?.invalidate(); tickTimer = nil
        validationTimer?.invalidate(); validationTimer = nil
    }

    func validateSelectedWindows() {
        let alive = Set(WindowEnumerator.browserWindows().map(\.windowID))
        if let w = windowA, !alive.contains(w.windowID) { windowA = nil }
        if let w = windowB, !alive.contains(w.windowID) { windowB = nil }
    }

    var summary: String {
        if controllerA.state.isTalking { return "TALKING TO \(preferences.labelA)" }
        if controllerB.state.isTalking { return "TALKING TO \(preferences.labelB)" }
        return "ALL MUTED"
    }

    @Published var windowA: BrowserWindow?
    @Published var windowB: BrowserWindow?

    var samePIDWarning: Bool {
        if let a = windowA, let b = windowB { return a.pid == b.pid }
        return false
    }

    struct HealthReport: Equatable {
        var blackHoleAInstalled: Bool
        var blackHoleBInstalled: Bool
        var samePIDWarning: Bool
        var noWindowsSelected: Bool
    }

    func currentHealth() -> HealthReport {
        let bh = BlackHoleDevices.detect()
        return HealthReport(
            blackHoleAInstalled: bh.a != nil,
            blackHoleBInstalled: bh.b != nil,
            samePIDWarning: samePIDWarning,
            noWindowsSelected: windowA == nil && windowB == nil
        )
    }

    func setWindow(_ window: BrowserWindow?, for side: Side) {
        switch side {
        case .a:
            windowA = window
            preferences.lastWindowAPID = window.map { Int($0.pid) }
        case .b:
            windowB = window
            preferences.lastWindowBPID = window.map { Int($0.pid) }
        }
    }

    func restoreLastWindows() {
        let snapshot = WindowEnumerator.browserWindows()
        if let pidA = preferences.lastWindowAPID,
           let restored = snapshot.first(where: { Int($0.pid) == pidA }) {
            windowA = restored
        }
        if let pidB = preferences.lastWindowBPID,
           let restored = snapshot.first(where: { Int($0.pid) == pidB }) {
            windowB = restored
        }
    }

    private func refreshAudioRouting(a: BrowserWindow?, b: BrowserWindow?) {
        if #available(macOS 14.2, *) {
            guard let router = audioRouter else { return }
            // Refuse same-PID routing — would just duplicate audio to both ears.
            if let pa = a?.pid, let pb = b?.pid, pa == pb {
                do { try router.update(pidA: nil, pidB: nil) }
                catch { print("[MixerViewModel] AudioRouter teardown failed: \(error)") }
                audioStatus = .samePIDRefused
                return
            }
            do {
                try router.update(pidA: a?.pid, pidB: b?.pid)
                audioStatus = .running
            } catch {
                print("[MixerViewModel] AudioRouter update failed: \(error)")
                audioStatus = .routerError(String(describing: error))
            }
        }
    }

    func startAudio() {
        do {
            try micMixer.start(inputDeviceUID: preferences.inputDeviceUID)
            audioStatus = .running
        } catch {
            let msg: String
            switch error {
            case MicMixer.MixerError.blackHoleAMissing:
                msg = "BlackHole-A device not found. Install BlackHole 2ch (renames to 'BlackHole-A' or default 'BlackHole 2ch' is fine)."
            case MicMixer.MixerError.blackHoleBMissing:
                msg = "BlackHole-B device not found. Run Scripts/install-blackhole-b.sh."
            default:
                msg = "Audio engine couldn't start: \(error.localizedDescription)"
            }
            audioStatus = .micMixerError(msg)
            print("[MixerViewModel] MicMixer start failed: \(error)")
            DMMLog.log("[MixerViewModel] MicMixer start failed: \(error)")
        }
    }

    private func restartMicMixer() {
        micMixer.stop()
        startAudio()
    }

    func ensureAccessibilityPermissionIfNeeded() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    private func controller(for side: Side) -> MeetingController {
        side == .a ? controllerA : controllerB
    }

    /// Whether Cmd+D mode drives mic mute for this side. Currently a single
    /// global preference; takes a side so callers stay correct if this ever
    /// becomes per-side.
    private func useCmdDMode(for side: Side) -> Bool {
        preferences.useCmdDForMicMute
    }

    private func syncCamera(side: Side, isTalking: Bool) {
        guard preferences.cameraFollowsTalker else { return }
        let pid: pid_t?
        let currentlyOn: Bool
        switch side {
        case .a:
            pid = windowA?.pid
            currentlyOn = cameraOnA
        case .b:
            pid = windowB?.pid
            currentlyOn = cameraOnB
        }
        let desiredOn = isTalking
        guard currentlyOn != desiredOn, let pid else { return }
        KeySender.sendCmdE(toPID: pid)
        switch side {
        case .a: cameraOnA = desiredOn
        case .b: cameraOnB = desiredOn
        }
    }

    /// Cmd+D mode mic sync. Mirror of syncCamera: only sends Cmd+D when the
    /// desired state differs from our tracked belief, to avoid toggle drift.
    /// Assumes both Meet windows start muted at app launch.
    private func syncMic(side: Side, isTalking: Bool) {
        let pid: pid_t?
        let currentlyUnmuted: Bool
        switch side {
        case .a:
            pid = windowA?.pid
            currentlyUnmuted = micUnmutedA
        case .b:
            pid = windowB?.pid
            currentlyUnmuted = micUnmutedB
        }
        let desiredUnmuted = isTalking
        guard currentlyUnmuted != desiredUnmuted, let pid else { return }
        KeySender.sendCmdD(toPID: pid)
        switch side {
        case .a: micUnmutedA = desiredUnmuted
        case .b: micUnmutedB = desiredUnmuted
        }
    }
}
