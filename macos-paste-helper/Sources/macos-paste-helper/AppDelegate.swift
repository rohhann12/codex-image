import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusController?
    private var pasteInterceptor: PasteInterceptor?
    private let pasteWorkflow = PasteWorkflow()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.log("App launched")
        logRuntimeIdentity()
        statusController = StatusController()
        statusController?.update(status: "Starting…")

        guard ensureAccessibilityPermission() else {
            Logger.shared.log("Accessibility permission missing")
            statusController?.update(status: "Accessibility needed")
            return
        }

        pasteInterceptor = PasteInterceptor(workflow: pasteWorkflow) { [weak self] message in
            Logger.shared.log("Status update: \(message)")
            self?.statusController?.update(status: message)
        }
        pasteInterceptor?.start()
        statusController?.update(status: "Ready")
        Logger.shared.log("App ready; log file at \(Logger.shared.path)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.log("App terminating")
        pasteInterceptor?.stop()
    }

    private func ensureAccessibilityPermission() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trustedWithoutPrompt = AXIsProcessTrusted()
        let trustedWithPrompt = AXIsProcessTrustedWithOptions(options)
        Logger.shared.log("Accessibility trust check: plain=\(trustedWithoutPrompt) prompted=\(trustedWithPrompt)")
        return trustedWithPrompt
    }

    private func logRuntimeIdentity() {
        let bundle = Bundle.main
        let bundleID = bundle.bundleIdentifier ?? "nil"
        let bundlePath = bundle.bundlePath
        let executablePath = bundle.executablePath ?? CommandLine.arguments.first ?? "nil"
        let processName = ProcessInfo.processInfo.processName
        let processID = ProcessInfo.processInfo.processIdentifier
        let launchArgs = CommandLine.arguments.joined(separator: " | ")
        let env = ProcessInfo.processInfo.environment
        let launchdService = env["LAUNCH_JOB_LABEL"] ?? "nil"
        let pwd = FileManager.default.currentDirectoryPath

        Logger.shared.log("Runtime identity: pid=\(processID) process=\(processName)")
        Logger.shared.log("Runtime identity: bundleID=\(bundleID)")
        Logger.shared.log("Runtime identity: bundlePath=\(bundlePath)")
        Logger.shared.log("Runtime identity: executablePath=\(executablePath)")
        Logger.shared.log("Runtime identity: cwd=\(pwd)")
        Logger.shared.log("Runtime identity: launchArgs=\(launchArgs)")
        Logger.shared.log("Runtime identity: launchdLabel=\(launchdService)")
    }
}
