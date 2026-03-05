import AppKit
import SwiftUI

final class HostSelectorPanel {
    private var panel: NSPanel?

    func show(sessions: [SSHSession], onSelect: @escaping (SSHSession) -> Void) {
        close()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 0),
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Push Clipboard To..."
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .visible
        panel.becomesKeyOnlyIfNeeded = false

        let view = HostSelectorView(sessions: sessions) { [weak self] session in
            onSelect(session)
            self?.close()
        } onCancel: { [weak self] in
            self?.close()
        }

        let hostingView = NSHostingView(rootView: view)
        panel.contentView = hostingView

        let height = CGFloat(sessions.count) * 44 + 80
        let frame = NSRect(x: 0, y: 0, width: 280, height: min(height, 400))
        panel.setContentSize(frame.size)
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        // Ensure the panel can receive key events
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel
    }

    func close() {
        panel?.close()
        panel = nil
    }
}

private struct HostSelectorView: View {
    let sessions: [SSHSession]
    let onSelect: (SSHSession) -> Void
    let onCancel: () -> Void

    @State private var selectedIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                ForEach(Array(sessions.enumerated()), id: \.element) { index, session in
                    Button(action: { onSelect(session) }) {
                        HStack {
                            Text(">_")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                            Text(session.displayName)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text("PID \(session.pid)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(index == selectedIndex
                        ? Color.accentColor.opacity(0.3)
                        : Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
            }
            .padding(8)

            Divider()

            HStack {
                Text("Up/Down to navigate, Enter to select")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(8)
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(sessions.count - 1, selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.return) {
            onSelect(sessions[selectedIndex])
            return .handled
        }
    }
}
