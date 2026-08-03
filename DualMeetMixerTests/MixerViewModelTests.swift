import XCTest
@testable import DualMeetMixer

final class MixerViewModelTests: XCTestCase {

    private var clock: TestClock!

    override func setUp() {
        super.setUp()
        clock = TestClock(now: Date(timeIntervalSince1970: 1_000_000))
    }

    /// Builds a VM backed by a fresh UserDefaults suite so tests never read
    /// the developer's real preferences (e.g., a customized keepAliveSeconds).
    private func makeVM(keepAliveSeconds: Int = 10) -> MixerViewModel {
        let prefs = Preferences(defaults: UserDefaults(suiteName: "MixerVMTests-\(UUID().uuidString)")!)
        prefs.keepAliveSeconds = keepAliveSeconds
        return MixerViewModel(keepAliveSeconds: keepAliveSeconds, clock: clock.now, preferences: prefs)
    }

    func test_initial_bothIdle() {
        let vm = makeVM()
        XCTAssertEqual(vm.controllerA.state, .idle)
        XCTAssertEqual(vm.controllerB.state, .idle)
    }

    func test_tapA_unmutes_A_andB_remainsIdle() {
        let vm = makeVM()
        vm.tap(.a)
        XCTAssertTrue(vm.controllerA.state.isTalking)
        XCTAssertEqual(vm.controllerB.state, .idle)
    }

    func test_tapB_whileA_talking_forces_A_idle_and_B_talking() {
        let vm = makeVM()
        vm.tap(.a)
        clock.advance(by: 3)              // A has 7s left
        vm.tap(.b)
        XCTAssertEqual(vm.controllerA.state, .idle, "Tapping B with time remaining on A must force A to idle.")
        XCTAssertTrue(vm.controllerB.state.isTalking)
    }

    func test_tapA_again_keepsAlive() {
        let vm = makeVM()
        vm.tap(.a)
        clock.advance(by: 6)
        vm.tap(.a)
        XCTAssertEqual(vm.controllerA.state.deadline, clock.now().addingTimeInterval(10))
    }

    func test_invariant_atMostOneTalking() {
        let vm = makeVM()
        for _ in 0..<10 {
            vm.tap(.a)
            XCTAssertFalse(vm.controllerB.state.isTalking)
            vm.tap(.b)
            XCTAssertFalse(vm.controllerA.state.isTalking)
        }
    }

    func test_tick_expires_talking_to_idle() {
        let vm = makeVM()
        vm.tap(.a)
        clock.advance(by: 11)
        vm.tick()
        XCTAssertEqual(vm.controllerA.state, .idle)
    }

    func test_summary_allMuted_whenBothIdle() {
        let vm = makeVM()
        XCTAssertEqual(vm.summary, "ALL MUTED")
    }

    func test_summary_talkingToA() {
        let prefs = Preferences(defaults: UserDefaults(suiteName: "MixerVMTests-\(UUID().uuidString)")!)
        prefs.labelA = "Google"
        prefs.labelB = "Apple"
        let vm = MixerViewModel(keepAliveSeconds: 10, clock: clock.now, preferences: prefs)
        vm.tap(.a)
        XCTAssertEqual(vm.summary, "TALKING TO Google")
    }

    func test_updatingPreferences_keepAliveSeconds_propagatesToControllers() {
        let suite = "MixerVMTests-\(UUID().uuidString)"
        let prefs = Preferences(defaults: UserDefaults(suiteName: suite)!)
        prefs.keepAliveSeconds = 10
        let vm = MixerViewModel(keepAliveSeconds: 10, clock: clock.now, preferences: prefs)
        XCTAssertEqual(vm.controllerA.keepAliveSeconds, 10)
        XCTAssertEqual(vm.controllerB.keepAliveSeconds, 10)

        prefs.keepAliveSeconds = 25
        XCTAssertEqual(vm.controllerA.keepAliveSeconds, 25)
        XCTAssertEqual(vm.controllerB.keepAliveSeconds, 25)
    }
}
