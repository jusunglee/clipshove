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

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(sessions, id: \.self) { session in
                        Button(action: { onSelect(session) }) {
                            HStack {
                                Image(systemName: "terminal")
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
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }
                .padding(8)
            }

            Divider()

            Button("Cancel") { onCancel() }
                .keyboardShortcut(.cancelAction)
                .padding(8)
        }
    }
}
