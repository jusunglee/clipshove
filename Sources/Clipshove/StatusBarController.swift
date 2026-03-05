import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    var pinnedHost: String?
    var onPushTriggered: (() -> Void)?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paperplane", accessibilityDescription: "Clipshove")
        }

        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        // Push action
        let pushItem = NSMenuItem(title: "Push Clipboard", action: #selector(pushClicked), keyEquivalent: "V")
        pushItem.keyEquivalentModifierMask = [.shift, .command]
        pushItem.target = self
        menu.addItem(pushItem)

        menu.addItem(.separator())

        // Active sessions
        let sessions = SSHSessionDetector.detect()
        if sessions.isEmpty {
            let noSessions = NSMenuItem(title: "No active SSH sessions", action: nil, keyEquivalent: "")
            noSessions.isEnabled = false
            menu.addItem(noSessions)
        } else {
            let header = NSMenuItem(title: "Active Sessions", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for session in sessions {
                let item = NSMenuItem(title: "  \(session.displayName) (PID \(session.pid))", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // Pin submenu
        let pinItem = NSMenuItem(title: "Pin to Host", action: nil, keyEquivalent: "")
        let pinMenu = NSMenu()

        let autoItem = NSMenuItem(title: "Auto (detect on push)", action: #selector(pinSelected(_:)), keyEquivalent: "")
        autoItem.target = self
        autoItem.representedObject = nil as String?
        if pinnedHost == nil {
            autoItem.state = .on
        }
        pinMenu.addItem(autoItem)

        if !sessions.isEmpty {
            pinMenu.addItem(.separator())
            for session in sessions {
                let item = NSMenuItem(title: session.displayName, action: #selector(pinSelected(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = session.host
                if pinnedHost == session.host {
                    item.state = .on
                }
                pinMenu.addItem(item)
            }
        }

        pinItem.submenu = pinMenu
        menu.addItem(pinItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    @objc private func pushClicked() {
        onPushTriggered?()
    }

    @objc private func pinSelected(_ sender: NSMenuItem) {
        pinnedHost = sender.representedObject as? String
    }
}
