import Foundation

enum Side: String, Equatable, Hashable, CaseIterable {
    case a, b

    var opposite: Side {
        self == .a ? .b : .a
    }
}
