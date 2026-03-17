import AppKit
import ApplicationServices

final class PasteInterceptor: @unchecked Sendable {
    private let allowedBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.warp.Warp-Stable",
        "com.github.wez.wezterm",
        "org.alacritty",
        "com.mitchellh.ghostty",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.vscodium"
    ]
    private let workflow: PasteWorkflow
    private let statusUpdate: (String) -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isInjectingPaste = false

    init(workflow: PasteWorkflow, statusUpdate: @escaping (String) -> Void) {
        self.workflow = workflow
        self.statusUpdate = statusUpdate
    }

    func start() {
        Logger.shared.log("Starting event tap")
        let mask = (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let interceptor = Unmanaged<PasteInterceptor>.fromOpaque(refcon).takeUnretainedValue()
            return interceptor.handle(proxy: proxy, type: type, event: event)
        }

        let ref = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: ref
        )

        guard let eventTap else {
            Logger.shared.log("Failed to create event tap")
            statusUpdate("Failed to start")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        Logger.shared.log("Event tap enabled")
        statusUpdate("Listening")
    }

    func stop() {
        Logger.shared.log("Stopping event tap")
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Logger.shared.log("Event tap disabled by system; re-enabling")
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let isCommandV = keyCode == 9 && flags.contains(.maskCommand)

        guard isCommandV else {
            return Unmanaged.passUnretained(event)
        }

        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "Unknown"
        let bundleID = app?.bundleIdentifier ?? "unknown.bundle"
        Logger.shared.log("Detected cmd+v in frontmost app '\(appName)' (\(bundleID))")

        guard shouldHandlePaste(for: app) else {
            Logger.shared.log("Ignoring cmd+v because frontmost app is not an allowed terminal")
            return Unmanaged.passUnretained(event)
        }

        if isInjectingPaste {
            isInjectingPaste = false
            Logger.shared.log("Allowing synthetic paste event to pass through")
            return Unmanaged.passUnretained(event)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if ClipboardImageSaver.shared.clipboardHasImage {
                Logger.shared.log("Clipboard contains image; starting save workflow")
                self.workflow.handlePaste { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success(let savedPath):
                        Logger.shared.log("Saved clipboard image to \(savedPath.path)")
                        self.statusUpdate("Saved \(savedPath.lastPathComponent)")
                        self.injectPathText("reference to the image is at \(savedPath.path)")
                    case .failure(let error):
                        Logger.shared.log("Paste workflow failed: \(error.localizedDescription)")
                        self.statusUpdate(error.localizedDescription)
                    }
                }
            } else {
                Logger.shared.log("Clipboard has no image; replaying normal paste")
                self.injectPlainPaste()
                self.statusUpdate("Plain paste")
            }
        }

        return nil
    }

    private func injectPathText(_ path: String) {
        Logger.shared.log("Injecting typed path into frontmost app: \(path)")
        isInjectingPaste = true

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            Logger.shared.log("Failed to create event source for typed path injection")
            statusUpdate("Paste injection failed")
            return
        }

        for scalar in path.unicodeScalars {
            guard
                let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else {
                Logger.shared.log("Failed to create keyboard events for character \(scalar)")
                statusUpdate("Paste injection failed")
                return
            }

            var codeUnit = UInt16(scalar.value)
            down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &codeUnit)
            up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &codeUnit)
            down.post(tap: .cgAnnotatedSessionEventTap)
            up.post(tap: .cgAnnotatedSessionEventTap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Logger.shared.log("Finished typed path injection")
            self.isInjectingPaste = false
        }
    }

    private func shouldHandlePaste(for app: NSRunningApplication?) -> Bool {
        guard let app, let bundleID = app.bundleIdentifier else {
            return false
        }

        guard allowedBundleIDs.contains(bundleID) else {
            return false
        }

        switch bundleID {
        case "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.vscodium":
            let looksLikeTerminal = focusedContextLooksLikeTerminal(pid: app.processIdentifier)
            Logger.shared.log("VS Code focused context terminal-like: \(looksLikeTerminal)")
            if looksLikeTerminal {
                Logger.shared.log("User focused on the TUI")
            } else {
                Logger.shared.log("User not focused on the TUI")
            }
            return looksLikeTerminal
        default:
            return true
        }
    }

    private func focusedContextLooksLikeTerminal(pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        let attributes = [kAXFocusedUIElementAttribute, kAXFocusedWindowAttribute]
        var snippets = [String]()

        for attribute in attributes {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, attribute as CFString, &value) == .success,
                  let element = value
            else {
                continue
            }
            collectContextStrings(from: element as! AXUIElement, limit: 80, into: &snippets)
        }

        let joined = snippets.joined(separator: " | ").lowercased()
        Logger.shared.log("VS Code focused context snippets: \(joined)")

        let keywords = [
            "terminal",
            "codex",
            "directory:",
            "gpt-5",
            "review on my current changes",
            "openai codex",
            "~/"
        ]

        return keywords.contains { joined.contains($0) }
    }

    private func collectContextStrings(from element: AXUIElement, limit: Int, into output: inout [String]) {
        guard limit > 0 else {
            return
        }

        for attribute in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute, kAXHelpAttribute, kAXRoleAttribute, kAXSubroleAttribute] {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
                continue
            }
            if let string = value as? String, !string.isEmpty {
                output.append(string)
            }
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement]
        else {
            return
        }

        var remaining = limit - 1
        for child in children {
            guard remaining > 0 else {
                break
            }
            collectContextStrings(from: child, limit: remaining, into: &output)
            remaining -= 1
        }
    }

    private func injectPlainPaste() {
        postSyntheticPaste()
    }

    private func postSyntheticPaste() {
        isInjectingPaste = true

        guard
            let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
            let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)
        else {
            Logger.shared.log("Failed to create synthetic cmd+v events")
            statusUpdate("Paste injection failed")
            return
        }

        Logger.shared.log("Posting synthetic cmd+v")
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }
}
