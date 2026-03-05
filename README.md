# Clipshove

[![Build & Release](https://github.com/jusunglee/clipshove/actions/workflows/build.yml/badge.svg)](https://github.com/jusunglee/clipshove/actions/workflows/build.yml)

A macOS menu bar app that pushes your local clipboard to a remote Mac's clipboard over SSH. Triggered by a global hotkey (**Shift+Cmd+V**).

Built for use with Tailscale — push your clipboard to any Mac you have an active SSH session to, with zero configuration on the remote end.

This was inspired by a problem I had with Claude Code: if you try to paste an image from local clipboard into a claude code inside a remote SSH session, it can't find it and suggests you SCP it instead. No way am I going to do all that. With clipshove, the flow is now just:

1. Copy image to clipboard (screenshot for example)
2. Command + Shift + V to shove it to remote
3. On remote claude code session, press Ctrl V to paste the image in

Easy peasy!

## How It Works

1. Copy something on your local Mac (text or image)
2. Press **Shift+Cmd+V**
3. Clipshove detects your active SSH sessions and pipes your clipboard via stdin to `pbcopy` on the remote Mac
4. The content is now on the remote clipboard

If you have one active SSH session, it pushes directly. Multiple sessions? A floating picker lets you choose (arrow keys + Enter). You can also pin a host via the menu bar to always push to it.

## Install

Download the latest DMG from [Releases](https://github.com/jusunglee/clipshove/releases), open it, and drag Clipshove to Applications.

### Build from Source

Requires macOS 14+ and Swift 5.9+.

```
git clone https://github.com/jusunglee/clipshove.git
cd clipshove
swift build -c release
cp .build/release/Clipshove /usr/local/bin/
```

Or just run in place:

```
swift run
```

## Usage

- **Shift+Cmd+V** — Push clipboard to remote host
- **Menu bar icon** — View active sessions, pin a host, or trigger a push manually

### Pinning a Host

Click the menu bar icon > **Pin to Host** > select a host. All future pushes go directly to that host without detection. Select **Auto** to go back to auto-detecting.

## Requirements

- **SSH key auth** to the remote Mac (Clipshove uses `BatchMode=yes` — no password prompts)
- **Accessibility permission** — needed for the global hotkey. macOS will prompt on first launch, or grant it in System Settings > Privacy & Security > Accessibility
- **`pbcopy`** on the remote Mac (standard on macOS)

## Design

- **No attack surface** — outbound SSH only, nothing listens on any port
- **Clipboard via stdin** — no shell escaping issues; handles quotes, newlines, emoji, binary-ish text
- **Image support** — images are converted to PNG, base64-encoded over SSH, and set on the remote clipboard via osascript
- **Non-activating UI** — the host picker and toasts don't steal focus from your current app
- **Fail-fast SSH** — `ConnectTimeout=5` and `BatchMode=yes` so it never hangs

## Dependencies

- [HotKey](https://github.com/soffes/HotKey) — global hotkey registration via Carbon events

## Technical Details

### Architecture

Clipshove runs as a pure `NSApplication` with `.accessory` activation policy — no dock icon, no main window, just a menu bar item. The app bootstraps manually (no SwiftUI `App` protocol) to get full control over the event loop and avoid the overhead of a SwiftUI lifecycle for what is essentially a background daemon with a status item.

### Hotkey Registration

The global hotkey is registered via the [HotKey](https://github.com/soffes/HotKey) library, which wraps the Carbon `InstallEventHandler` API. This is the only reliable way to capture system-wide key combos on macOS — it requires Accessibility permission (`AXIsProcessTrusted()`), which the app checks on launch and prompts for if missing.

### SSH Session Detection

When the hotkey fires, Clipshove needs to know where to push. It detects active outbound SSH connections by shelling out to `ps -eo pid,command` and parsing the output. For each line containing `/usr/bin/ssh` or `ssh`:

1. Filters out non-connection processes (`ssh-agent`, `ssh-add`, `sshd`)
2. Tokenizes the command string and walks the argument list
3. Skips flags that consume a value (`-p`, `-i`, `-J`, `-o`, `-F`, `-L`, `-R`, `-D`, `-W`, etc.) by advancing the index by 2
4. Skips boolean flags by advancing by 1
5. The first non-flag argument is the destination — strips `user@` prefix if present
6. Deduplicates by hostname

This approach works regardless of SSH port, jump hosts, or config aliases. It requires no elevated privileges and runs in ~5ms.

### Clipboard Push Mechanism

The actual push is the core trick. Clipshove spawns a `Process` running:

```
/usr/bin/ssh -o BatchMode=yes -o ConnectTimeout=5 <host> pbcopy
```

The clipboard content is written to the process's **stdin pipe**, then the pipe is closed. This is critical — the content never touches shell arguments, command strings, or environment variables. It goes directly from `NSPasteboard` > `Data` > `Pipe.fileHandleForWriting` > SSH transport > remote `pbcopy`'s stdin. This means:

- No escaping needed for quotes, backslashes, newlines, or special characters
- No argument length limits (ARG_MAX)
- Binary-safe for any UTF-8 content
- No shell interpretation on either end

For images, the flow is: `NSPasteboard` TIFF > PNG conversion > base64 encode > SSH pipe > remote base64 decode to temp file > `osascript` sets clipboard from PNG file > cleanup.

`BatchMode=yes` ensures SSH never prompts for a password (it either authenticates via key or fails immediately). `ConnectTimeout=5` caps the TCP connection timeout so a dead host doesn't hang the app.

The process runs asynchronously via `terminationHandler` — the main thread stays responsive while SSH does its thing. The result (success or stderr output) is dispatched back to the main queue for the toast.

### UI Layer

**Menu bar**: An `NSStatusItem` with a clipboard emoji. The menu is rebuilt on every click so the session list is always fresh.

**Host selector**: When multiple SSH sessions are detected, Clipshove shows a `KeyablePanel` (NSPanel subclass) with `.floating` window level. Arrow keys navigate, Enter selects, Esc cancels. The panel content is a SwiftUI `View` hosted via `NSHostingView`.

**Toasts**: Success/failure feedback uses `NSPanel` with `NSVisualEffectView` (`.hudWindow` material) for the frosted-glass look. Toasts auto-dismiss after 2 seconds. No notification permissions required.

### Why Not Just Use `osascript` / AppleScript?

A common approach is `ssh host "osascript -e 'set the clipboard to \"...\"'"`. This breaks on special characters, hits argument length limits, requires shell escaping on both sides, and invokes a full AppleScript interpreter. Piping to `pbcopy` via stdin avoids all of these problems.
