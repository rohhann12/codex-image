import AppKit

@MainActor
final class StatusController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusMenuItem = NSMenuItem(title: "Status: Starting…", action: nil, keyEquivalent: "")

    override init() {
        super.init()

        if let button = item.button {
            button.title = "PastePath"
        }

        let menu = NSMenu()
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
    }

    func update(status: String) {
        statusMenuItem.title = "Status: \(status)"
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
