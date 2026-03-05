import AppKit

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    var pinnedHost: String?
    var onPushTriggered: (() -> Void)?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.title = "\u{1F4CB}"
            button.action = #selector(statusBarClicked)
            button.target = self
        }
    }

    @objc private func statusBarClicked() {
        buildMenu()
        statusItem.menu = menu
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            button.performClick(nil)
            DispatchQueue.main.async {
                self.statusItem.menu = nil
            }
        }
    }

    private func buildMenu() {
        menu.removeAllItems()

        let pushItem = NSMenuItem(title: "Push Clipboard", action: #selector(pushClicked), keyEquivalent: "V")
        pushItem.keyEquivalentModifierMask = [.shift, .command]
        pushItem.target = self
        menu.addItem(pushItem)

        menu.addItem(.separator())

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

        if UpdateChecker.updateAvailable, let latest = UpdateChecker.latestVersion {
            let updateItem = NSMenuItem(
                title: "Update Available (v\(latest))",
                action: #selector(openUpdate),
                keyEquivalent: ""
            )
            updateItem.target = self
            menu.addItem(updateItem)
            menu.addItem(.separator())
        }

        let versionItem = NSMenuItem(title: "v\(UpdateChecker.currentVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    @objc private func pushClicked() {
        onPushTriggered?()
    }

    @objc private func pinSelected(_ sender: NSMenuItem) {
        pinnedHost = sender.representedObject as? String
    }

    @objc private func openUpdate() {
        if let urlStr = UpdateChecker.releaseURL, let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        }
    }
}
