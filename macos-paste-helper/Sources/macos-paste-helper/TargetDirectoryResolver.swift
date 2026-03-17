import AppKit
import ApplicationServices
import Foundation

struct TargetDirectoryResolver {
    enum DirectoryError: LocalizedError {
        case notFound

        var errorDescription: String? {
            "Could not detect the current folder"
        }
    }

    func resolveDirectory() throws -> URL {
        if let app = NSWorkspace.shared.frontmostApplication {
            Logger.shared.log("Resolving directory for frontmost app '\(app.localizedName ?? "Unknown")' (\(app.bundleIdentifier ?? "unknown.bundle"))")
            if let resolved = try resolveForKnownApp(app) {
                Logger.shared.log("Resolved directory via known-app strategy: \(resolved.path)")
                return resolved
            }
            if let fromTitle = resolveFromFocusedWindowTitle(app.processIdentifier) {
                Logger.shared.log("Resolved directory via focused window title: \(fromTitle.path)")
                return fromTitle
            }
            Logger.shared.log("Known-app and title strategies failed for frontmost app")
        }
        throw DirectoryError.notFound
    }

    private func resolveForKnownApp(_ app: NSRunningApplication) throws -> URL? {
        switch app.bundleIdentifier {
        case "com.apple.Terminal":
            Logger.shared.log("Trying Terminal resolver")
            if let tty = try appleScript("tell application \"Terminal\" to tty of selected tab of front window") {
                Logger.shared.log("Terminal tty: \(tty)")
                return cwdForTTY(tty)
            }
        case "com.googlecode.iterm2":
            Logger.shared.log("Trying iTerm2 resolver")
            if let tty = try appleScript("tell application \"iTerm2\" to tty of current session of current window") {
                Logger.shared.log("iTerm2 tty: \(tty)")
                return cwdForTTY(tty)
            }
        case "com.openai.codex":
            Logger.shared.log("Trying Codex accessibility resolver")
            if let resolved = resolveFromCodexAccessibility(app.processIdentifier) {
                return resolved
            }
        case "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.vscodium":
            Logger.shared.log("Trying VS Code accessibility resolver")
            if let resolved = resolveFromEditorAccessibility(app.processIdentifier, appName: app.localizedName ?? "VS Code") {
                return resolved
            }
        default:
            break
        }
        return nil
    }

    private func resolveFromFocusedWindowTitle(_ pid: pid_t) -> URL? {
        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
              let focusedWindow = focusedWindowRef
        else {
            return nil
        }

        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedWindow as! AXUIElement, kAXTitleAttribute as CFString, &titleRef) == .success,
              let title = titleRef as? String
        else {
            return nil
        }

        return pathFrom(title: title)
    }

    private func resolveFromCodexAccessibility(_ pid: pid_t) -> URL? {
        let appElement = AXUIElementCreateApplication(pid)
        guard let focusedWindow = axElement(appElement, attribute: kAXFocusedWindowAttribute) else {
            Logger.shared.log("Codex accessibility: focused window unavailable")
            return nil
        }

        var collected = [String]()
        collectAXStrings(from: focusedWindow, limit: 400, into: &collected)
        Logger.shared.log("Codex accessibility collected \(collected.count) text candidates")

        let prioritized = collected.sorted { lhs, rhs in
            scoreCandidate(lhs) > scoreCandidate(rhs)
        }

        for candidate in prioritized {
            if let resolved = pathFrom(text: candidate) {
                Logger.shared.log("Codex accessibility matched directory candidate from text: \(candidate)")
                return resolved
            }
        }

        Logger.shared.log("Codex accessibility did not yield a valid directory")
        return nil
    }

    private func resolveFromEditorAccessibility(_ pid: pid_t, appName: String) -> URL? {
        let appElement = AXUIElementCreateApplication(pid)
        guard let focusedWindow = axElement(appElement, attribute: kAXFocusedWindowAttribute) else {
            Logger.shared.log("\(appName) accessibility: focused window unavailable")
            return nil
        }

        var collected = [String]()
        collectAXStrings(from: focusedWindow, limit: 600, into: &collected)
        Logger.shared.log("\(appName) accessibility collected \(collected.count) text candidates")

        let prioritized = collected.sorted { lhs, rhs in
            scoreCandidate(lhs) > scoreCandidate(rhs)
        }

        for candidate in prioritized {
            if let resolved = pathFrom(text: candidate) {
                Logger.shared.log("\(appName) accessibility matched directory candidate from text: \(candidate)")
                return resolved
            }
        }

        Logger.shared.log("\(appName) accessibility did not yield a valid directory")
        return nil
    }

    private func collectAXStrings(from element: AXUIElement, limit: Int, into output: inout [String]) {
        guard limit > 0 else {
            return
        }

        for attribute in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute, kAXHelpAttribute] {
            if let string = axString(element, attribute: attribute), !string.isEmpty {
                output.append(string)
            }
        }

        guard let children = axChildren(element) else {
            return
        }

        var remaining = limit - 1
        for child in children {
            guard remaining > 0 else {
                break
            }
            collectAXStrings(from: child, limit: remaining, into: &output)
            remaining -= 1
        }
    }

    private func scoreCandidate(_ text: String) -> Int {
        var score = 0
        if text.contains("/") { score += 2 }
        if text.contains("~") { score += 2 }
        if text.localizedCaseInsensitiveContains("directory") { score += 3 }
        if text.localizedCaseInsensitiveContains("workspace") { score += 3 }
        if text.localizedCaseInsensitiveContains("cwd") { score += 3 }
        if text.localizedCaseInsensitiveContains("folder") { score += 2 }
        if text.localizedCaseInsensitiveContains("project") { score += 2 }
        if text.contains("Users/") { score += 3 }
        return score
    }

    private func pathFrom(text: String) -> URL? {
        let patterns = [
            #"~\/[A-Za-z0-9._\-\/ ]+"#,
            #"\/Users\/[A-Za-z0-9._\-\/ ]+"#,
            #"\/[A-Za-z0-9._\-]+(?:\/[A-Za-z0-9._\- ]+)+"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)
            for match in matches {
                guard let matchRange = Range(match.range, in: text) else {
                    continue
                }
                let candidate = String(text[matchRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'.,:;)]}"))
                if let resolved = existingDirectoryURL(from: candidate) {
                    return resolved
                }
            }
        }

        if let directory = existingDirectoryURL(from: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return directory
        }

        return nil
    }

    private func pathFrom(title: String) -> URL? {
        let tokens = title
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters.subtracting(CharacterSet(charactersIn: "/~._-"))))
            .filter { !$0.isEmpty }

        for token in tokens.reversed() {
            let expanded = NSString(string: token).expandingTildeInPath
            if expanded.hasPrefix("/"), FileManager.default.fileExists(atPath: expanded) {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue {
                    return URL(fileURLWithPath: expanded, isDirectory: true)
                }
            }
        }

        return nil
    }

    private func existingDirectoryURL(from pathText: String) -> URL? {
        let expanded = NSString(string: pathText).expandingTildeInPath
        guard expanded.hasPrefix("/") else {
            return nil
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        return URL(fileURLWithPath: expanded, isDirectory: true)
    }

    private func axElement(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func axChildren(_ element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? [AXUIElement]
    }

    private func axString(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func appleScript(_ source: String) throws -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            Logger.shared.log("AppleScript source failed to initialize")
            return nil
        }
        let output = script.executeAndReturnError(&error)
        if error != nil {
            Logger.shared.log("AppleScript failed: \(error!)")
            return nil
        }
        return output.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cwdForTTY(_ tty: String) -> URL? {
        let ttyName = URL(fileURLWithPath: tty).lastPathComponent
        guard !ttyName.isEmpty else {
            Logger.shared.log("TTY name empty")
            return nil
        }

        guard let psOutput = run("/bin/ps", ["-t", ttyName, "-o", "pid=,state=,comm="]) else {
            Logger.shared.log("ps lookup failed for tty \(ttyName)")
            return nil
        }

        let lines = psOutput
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let preferred = lines.first(where: { $0.contains("+") }) ?? lines.last
        guard let candidate = preferred else {
            Logger.shared.log("No process candidate found for tty \(ttyName)")
            return nil
        }

        let parts = candidate.split(separator: " ", omittingEmptySubsequences: true)
        guard let pidPart = parts.first, let pid = Int32(pidPart) else {
            Logger.shared.log("Could not parse pid from tty candidate: \(candidate)")
            return nil
        }

        guard let lsofOutput = run("/usr/sbin/lsof", ["-a", "-p", String(pid), "-d", "cwd", "-Fn"]) else {
            Logger.shared.log("lsof cwd lookup failed for pid \(pid)")
            return nil
        }

        let pathLine = lsofOutput
            .split(separator: "\n")
            .map(String.init)
            .first { $0.hasPrefix("n/") }

        guard let pathLine else {
            Logger.shared.log("No cwd line found in lsof output for pid \(pid)")
            return nil
        }

        let path = String(pathLine.dropFirst())
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            Logger.shared.log("Resolved tty cwd is not a directory: \(path)")
            return nil
        }
        Logger.shared.log("Resolved tty cwd: \(path)")
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func run(_ launchPath: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return nil
            }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
