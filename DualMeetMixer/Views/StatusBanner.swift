import SwiftUI

struct StatusBanner: View {
    let icon: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(message)
                .font(.callout)
                .foregroundStyle(.white)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.18)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.5)))
    }
}
