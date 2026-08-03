import Foundation
import CoreGraphics

struct BrowserWindow: Identifiable, Equatable, Hashable {
    let pid: pid_t
    let windowID: CGWindowID
    let appName: String
    let title: String
    let bundleIdentifier: String?

    var id: CGWindowID { windowID }

    var displayString: String {
        title.isEmpty ? "\(appName) (untitled)" : "\(appName) — \(title)"
    }
}
