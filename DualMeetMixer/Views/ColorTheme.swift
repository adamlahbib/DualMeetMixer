import SwiftUI

enum ColorTheme {
    static let purpleA = Color(red: 0.55, green: 0.27, blue: 0.95)
    static let redB = Color(red: 0.95, green: 0.27, blue: 0.27)
    static let surface = Color.black
    static let cardOutline = Color.white.opacity(0.1)
    static let dim = Color.white.opacity(0.4)
    static let mutedText = Color.white.opacity(0.6)

    static func tint(for side: Side) -> Color {
        side == .a ? purpleA : redB
    }
}
