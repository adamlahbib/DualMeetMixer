import SwiftUI

struct CountdownRing: View {
    /// Fraction of time remaining, 0.0 ... 1.0. 1.0 = full ring.
    let progress: Double
    let secondsRemaining: Int
    let tint: Color
    let isActive: Bool

    private let lineWidth: CGFloat = 8
    private let diameter: CGFloat = 100

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
                .frame(width: diameter, height: diameter)
            Circle()
                .trim(from: 0, to: max(0.0, min(1.0, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: diameter, height: diameter)
                .opacity(isActive ? 1 : 0.35)
            Text(isActive ? "\(secondsRemaining)s" : "—")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(isActive ? 1 : 0.5))
        }
    }
}

#Preview {
    HStack(spacing: 40) {
        CountdownRing(progress: 0.7, secondsRemaining: 7, tint: ColorTheme.purpleA, isActive: true)
        CountdownRing(progress: 0.0, secondsRemaining: 0, tint: ColorTheme.redB, isActive: false)
    }
    .padding(40)
    .background(Color.black)
}
