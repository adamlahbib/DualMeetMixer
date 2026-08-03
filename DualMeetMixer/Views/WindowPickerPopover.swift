import SwiftUI

struct WindowPickerPopover: View {
    let windows: [BrowserWindow]
    let onPick: (BrowserWindow) -> Void
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Filter…", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.white.opacity(0.04))
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered, id: \.id) { window in
                        Button(action: { onPick(window) }) {
                            HStack(spacing: 10) {
                                Image(systemName: bundleIcon(for: window.bundleIdentifier))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(window.title)
                                        .lineLimit(1)
                                        .foregroundStyle(.white)
                                    Text("\(window.appName) · pid \(window.pid)")
                                        .font(.caption)
                                        .foregroundStyle(ColorTheme.mutedText)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
            }
            .frame(maxHeight: 320)
            if filtered.isEmpty {
                Text("No browser windows found.")
                    .foregroundStyle(ColorTheme.mutedText)
                    .padding()
            }
        }
        .frame(width: 380)
        .background(Color(white: 0.1))
    }

    private var filtered: [BrowserWindow] {
        if query.isEmpty { return windows }
        let q = query.lowercased()
        return windows.filter {
            $0.title.lowercased().contains(q) || $0.appName.lowercased().contains(q)
        }
    }

    private func bundleIcon(for bundleID: String?) -> String {
        switch bundleID {
        case "com.apple.Safari": return "safari"
        case let id? where id.contains("Chrome"): return "globe"
        case let id? where id.contains("firefox"): return "flame"
        default: return "globe"
        }
    }
}
