import SwiftUI

struct TalkButton: View {
    let tint: Color
    let isActive: Bool
    let action: () -> Void
    @State private var pulse = false

    private let diameter: CGFloat = 130

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(tint.opacity(isActive ? 0.95 : 0.55))
                    .frame(width: diameter, height: diameter)
                    .shadow(color: tint.opacity(isActive ? 0.85 : 0.0),
                            radius: isActive ? (pulse ? 32 : 22) : 0, x: 0, y: 0)
                    .scaleEffect(isActive ? (pulse ? 1.02 : 1.00) : 1.0)
                Image(systemName: "mic.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                Text("TALK")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(y: 30)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isActive)
        .onAppear { startPulse() }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
            pulse.toggle()
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        TalkButton(tint: Color(red: 0.55, green: 0.27, blue: 0.95), isActive: true) {}
        TalkButton(tint: Color(red: 0.95, green: 0.27, blue: 0.27), isActive: false) {}
    }
    .padding(40)
    .background(Color.black)
}
