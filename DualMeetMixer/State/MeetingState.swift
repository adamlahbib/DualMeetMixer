import Foundation

enum MeetingState: Equatable {
    case idle
    case talking(deadline: Date)

    var isTalking: Bool {
        if case .talking = self { return true }
        return false
    }

    var deadline: Date? {
        if case .talking(let d) = self { return d }
        return nil
    }
}
