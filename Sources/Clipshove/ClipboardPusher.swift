import AppKit
import Foundation

enum PushResult {
    case success(String) // description of what was pushed
    case emptyClipboard
    case sshFailed(String)
}

enum ClipboardPusher {
    static func push(to host: String, completion: @escaping (PushResult) -> Void) {
        let pb = NSPasteboard.general

        // Try text first
        if let content = pb.string(forType: .string), !content.isEmpty {
            let contentData = Data(content.utf8)
            if contentData.count > 1_000_000 {
                print("[Clipshove] Warning: clipboard content is over 1MB (\(contentData.count) bytes)")
            }
            runSSH(host: host, command: "pbcopy", data: contentData) { result in
                switch result {
                case .success:
                    completion(.success("text"))
                case .failure(let err):
                    completion(.sshFailed(err))
                }
            }
            return
        }

        // Try image (TIFF is the standard pasteboard image type on macOS)
        if let imgData = pb.data(forType: .tiff) {
            // Convert to PNG for transfer
            guard let bitmap = NSBitmapImageRep(data: imgData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                completion(.emptyClipboard)
                return
            }

            if pngData.count > 10_000_000 {
                print("[Clipshove] Warning: image is over 10MB (\(pngData.count) bytes)")
            }

            // Remote script: decode base64 PNG and set clipboard via osascript
            let remoteScript = """
                tmpfile=$(mktemp /tmp/clipshove.XXXXXX.png) && \
                base64 -D > "$tmpfile" && \
                osascript -e 'set the clipboard to (read (POSIX file "'$tmpfile'") as «class PNGf»)' && \
                rm -f "$tmpfile"
                """

            let b64Data = pngData.base64EncodedData()

            runSSH(host: host, command: remoteScript, data: b64Data) { result in
                switch result {
                case .success:
                    completion(.success("image"))
                case .failure(let err):
                    completion(.sshFailed(err))
                }
            }
            return
        }

        completion(.emptyClipboard)
    }

    private enum SSHResult {
        case success
        case failure(String)
    }

    private static func runSSH(host: String, command: String, data: Data, completion: @escaping (SSHResult) -> Void) {
        let process = Process()
        let stdinPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=5",
            host,
            command
        ]
        process.standardInput = stdinPipe
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        process.terminationHandler = { proc in
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                if proc.terminationStatus == 0 {
                    completion(.success)
                } else {
                    completion(.failure(stderrStr.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
        }

        do {
            try process.run()
            stdinPipe.fileHandleForWriting.write(data)
            stdinPipe.fileHandleForWriting.closeFile()
        } catch {
            completion(.failure(error.localizedDescription))
        }
    }
}
