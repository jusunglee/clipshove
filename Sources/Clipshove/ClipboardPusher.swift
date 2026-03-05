import AppKit
import Foundation

enum PushResult {
    case success
    case emptyClipboard
    case sshFailed(String)
}

enum ClipboardPusher {
    static func push(to host: String, completion: @escaping (PushResult) -> Void) {
        guard let content = NSPasteboard.general.string(forType: .string), !content.isEmpty else {
            completion(.emptyClipboard)
            return
        }

        let contentData = Data(content.utf8)

        if contentData.count > 1_000_000 {
            // Warn but still proceed — the plan says "warning" not "block"
            print("Warning: clipboard content is over 1MB (\(contentData.count) bytes)")
        }

        let process = Process()
        let stdinPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=5",
            host,
            "pbcopy"
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
                    completion(.sshFailed(stderrStr.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
        }

        do {
            try process.run()
            stdinPipe.fileHandleForWriting.write(contentData)
            stdinPipe.fileHandleForWriting.closeFile()
        } catch {
            completion(.sshFailed(error.localizedDescription))
        }
    }
}
