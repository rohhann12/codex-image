import Foundation

final class Logger: @unchecked Sendable {
    static let shared = Logger()

    private let queue = DispatchQueue(label: "com.codex.pastepath.logger")
    private let logURL: URL
    private let formatter: ISO8601DateFormatter

    private init() {
        let logsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        logURL = logsDirectory.appendingPathComponent("PastePath.log")
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    var path: String {
        logURL.path
    }

    func log(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        queue.async {
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logURL.path) {
                    if let handle = try? FileHandle(forWritingTo: self.logURL) {
                        defer { try? handle.close() }
                        _ = try? handle.seekToEnd()
                        try? handle.write(contentsOf: data)
                    }
                } else {
                    try? data.write(to: self.logURL, options: .atomic)
                }
            }
            fputs(line, stderr)
        }
    }
}
