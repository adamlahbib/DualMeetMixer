import AppKit

enum WindowEnumerator {

    /// Browsers we surface in the picker. Add bundle IDs as needed.
    static let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Canary",
        "company.thebrowser.Browser",        // Arc
        "com.vivaldi.Vivaldi",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition"
    ]

    static func browserWindows() -> [BrowserWindow] {
        let listOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(listOptions, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let runningApps = Dictionary(uniqueKeysWithValues:
            NSWorkspace.shared.runningApplications
                .compactMap { app -> (pid_t, NSRunningApplication)? in
                    return (app.processIdentifier, app)
                })

        var windows: [BrowserWindow] = []
        for entry in info {
            guard
                let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                let app = runningApps[pid],
                let bundleID = app.bundleIdentifier,
                browserBundleIDs.contains(bundleID),
                let windowID = entry[kCGWindowNumber as String] as? CGWindowID,
                let layer = entry[kCGWindowLayer as String] as? Int,
                layer == 0   // ignore menus, panels
            else { continue }

            let title = (entry[kCGWindowName as String] as? String) ?? ""
            // Skip windows with no title (often background panels)
            if title.isEmpty { continue }

            let appName = app.localizedName ?? bundleID
            windows.append(BrowserWindow(
                pid: pid,
                windowID: windowID,
                appName: appName,
                title: title,
                bundleIdentifier: bundleID
            ))
        }
        return windows.sorted { $0.appName < $1.appName }
    }
}
