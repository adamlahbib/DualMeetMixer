import Foundation

/// File-based logger for diagnostics. NSLog/print get masked as <private> in
/// macOS unified logging; writing to a file bypasses that and lets us read
/// exactly what happened.
///
/// Tail the log with: `tail -f ~/Library/Logs/DualMeetMixer.log`
enum DMMLog {

    private static let queue = DispatchQueue(label: "com.adamlahbib.DualMeetMixer.log")
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private static let fileURL: URL = {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let url = logs.appendingPathComponent("DualMeetMixer.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        return url
    }()

    static func log(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        queue.async {
            if let data = line.data(using: .utf8),
               let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
            FileHandle.standardError.write(line.data(using: .utf8) ?? Data())
        }
    }
}
