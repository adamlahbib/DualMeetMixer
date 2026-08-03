import XCTest
@testable import DualMeetMixer

final class MeetingControllerTests: XCTestCase {

    private var clock: TestClock!

    override func setUp() {
        super.setUp()
        clock = TestClock(now: Date(timeIntervalSince1970: 1_000_000))
    }

    func test_initialState_isIdle() {
        let c = MeetingController(side: .a, keepAliveSeconds: 10, clock: clock.now)
        XCTAssertEqual(c.state, .idle)
    }

    func test_tap_idle_transitionsToTalking_withDeadlinePlusKeepAlive() {
        let c = MeetingController(side: .a, keepAliveSeconds: 10, clock: clock.now)
        c.tap()
        XCTAssertTrue(c.state.isTalking)
        XCTAssertEqual(c.state.deadline, clock.now().addingTimeInterval(10))
    }

    func test_tap_talking_resetsDeadline_keepAlive() {
        let c = MeetingController(side: .a, keepAliveSeconds: 10, clock: clock.now)
        c.tap()
        clock.advance(by: 6)              // 4 seconds remaining
        let oldDeadline = c.state.deadline!
        c.tap()                           // keep-alive press
        XCTAssertEqual(c.state.deadline, clock.now().addingTimeInterval(10))
        XCTAssertGreaterThan(c.state.deadline!, oldDeadline)
    }

    func test_forceIdle_setsToIdle() {
        let c = MeetingController(side: .a, keepAliveSeconds: 10, clock: clock.now)
        c.tap()
        c.forceIdle()
        XCTAssertEqual(c.state, .idle)
    }

    func test_tick_pastDeadline_transitionsToIdle() {
        let c = MeetingController(side: .a, keepAliveSeconds: 10, clock: clock.now)
        c.tap()
        clock.advance(by: 11)
        c.tick()
        XCTAssertEqual(c.state, .idle)
    }

    func test_tick_beforeDeadline_staysTalking() {
        let c = MeetingController(side: .a, keepAliveSeconds: 10, clock: clock.now)
        c.tap()
        clock.advance(by: 5)
        c.tick()
        XCTAssertTrue(c.state.isTalking)
    }

    func test_remainingSeconds_idle_returnsZero() {
        let c = MeetingController(side: .a, keepAliveSeconds: 10, clock: clock.now)
        XCTAssertEqual(c.remainingSeconds(now: clock.now()), 0)
    }

    func test_remainingSeconds_talking_returnsExactRemaining() {
        let c = MeetingController(side: .a, keepAliveSeconds: 10, clock: clock.now)
        c.tap()
        clock.advance(by: 3)
        XCTAssertEqual(c.remainingSeconds(now: clock.now()), 7, accuracy: 0.001)
    }
}

final class TestClock {
    private(set) var current: Date
    init(now: Date) { self.current = now }
    func now() -> Date { current }
    func advance(by seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}
