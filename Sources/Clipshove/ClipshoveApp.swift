import AppKit
import HotKey

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private var hotKey: HotKey!
    private let hostSelector = HostSelectorPanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prompt for accessibility if needed (non-blocking)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        statusBar = StatusBarController()
        statusBar.onPushTriggered = { [weak self] in
            self?.handlePush()
        }

        hotKey = HotKey(key: .v, modifiers: [.shift, .command])
        hotKey.keyDownHandler = { [weak self] in
            self?.handlePush()
        }

        UpdateChecker.check()
    }

    private func handlePush() {
        // If pinned, push directly
        if let pinned = statusBar.pinnedHost {
            pushTo(host: pinned)
            return
        }

        let sessions = SSHSessionDetector.detect()

        switch sessions.count {
        case 0:
            showToast("No active SSH sessions")
        case 1:
            pushTo(host: sessions[0].host)
        default:
            hostSelector.show(sessions: sessions) { [weak self] session in
                self?.pushTo(host: session.host)
            }
        }
    }

    private func pushTo(host: String) {
        ClipboardPusher.push(to: host) { [weak self] result in
            switch result {
            case .success(let kind):
                self?.showToast("Pushed \(kind) to \(host)")
            case .emptyClipboard:
                self?.showToast("Clipboard is empty")
            case .sshFailed(let error):
                self?.showToast("Failed: \(error.isEmpty ? "SSH error" : error)")
            }
        }
    }

    // MARK: - Toast

    private var toastPanel: NSPanel?
    private var toastTimer: Timer?

    private func showToast(_ message: String) {
        toastTimer?.invalidate()
        toastPanel?.close()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 44),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let bg = NSVisualEffectView(frame: panel.contentView!.bounds)
        bg.autoresizingMask = [.width, .height]
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 10

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.frame = bg.bounds
        label.autoresizingMask = [.width, .height]

        bg.addSubview(label)
        panel.contentView?.addSubview(bg)

        // Position near top center of main screen
        if let screen = NSScreen.main {
            let x = screen.frame.midX - 150
            let y = screen.frame.maxY - 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        toastPanel = panel

        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.toastPanel?.close()
            self?.toastPanel = nil
        }
    }
}

// MARK: - Entry Point

@main
enum Clipshove {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate

        app.run()
    }
}
