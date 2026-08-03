import Foundation
import Combine

final class MeetingController: ObservableObject {

    let side: Side
    private(set) var keepAliveSeconds: Int
    private let clock: () -> Date

    @Published private(set) var state: MeetingState = .idle

    init(side: Side, keepAliveSeconds: Int, clock: @escaping () -> Date = Date.init) {
        self.side = side
        self.keepAliveSeconds = keepAliveSeconds
        self.clock = clock
    }

    func tap() {
        let deadline = clock().addingTimeInterval(TimeInterval(keepAliveSeconds))
        state = .talking(deadline: deadline)
    }

    func forceIdle() {
        state = .idle
    }

    func tick() {
        guard case .talking(let deadline) = state else { return }
        if clock() >= deadline {
            state = .idle
        }
    }

    func remainingSeconds(now: Date) -> TimeInterval {
        guard case .talking(let deadline) = state else { return 0 }
        return max(0, deadline.timeIntervalSince(now))
    }

    func updateKeepAlive(seconds: Int) {
        self.keepAliveSeconds = seconds
    }
}
