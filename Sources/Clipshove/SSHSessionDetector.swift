import Foundation

struct SSHSession: Hashable {
    let pid: Int32
    let host: String
    let displayName: String
}

enum SSHSessionDetector {
    /// Flags that consume the next argument (so we skip it when looking for the host)
    private static let flagsWithValue: Set<String> = [
        "-p", "-i", "-J", "-o", "-F", "-L", "-R", "-D", "-W",
        "-b", "-c", "-E", "-e", "-l", "-m", "-O", "-Q", "-S", "-w"
    ]

    static func detect() -> [SSHSession] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-eo", "pid,command"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var seen = Set<String>()
        var sessions: [SSHSession] = []

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("/usr/bin/ssh ") || trimmed.contains(" ssh ") else { continue }

            // Exclude non-connection ssh processes
            let lower = trimmed.lowercased()
            if lower.contains("ssh-agent") || lower.contains("ssh-add") || lower.contains("sshd") {
                continue
            }

            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }

            let command = String(parts[1])
            guard let host = parseHost(from: command) else { continue }

            if seen.insert(host).inserted {
                sessions.append(SSHSession(pid: pid, host: host, displayName: host))
            }
        }

        return sessions
    }

    private static func parseHost(from command: String) -> String? {
        let args = command.components(separatedBy: " ").filter { !$0.isEmpty }

        // Find the ssh binary, then parse args after it
        guard let sshIndex = args.firstIndex(where: { $0.hasSuffix("ssh") }) else { return nil }

        var i = sshIndex + 1
        while i < args.count {
            let arg = args[i]

            if arg == "--" {
                // Next arg after -- is the destination
                i += 1
                break
            }

            if arg.hasPrefix("-") && arg != "-" {
                if flagsWithValue.contains(arg) {
                    i += 2 // skip flag and its value
                } else {
                    i += 1 // boolean flag
                }
                continue
            }

            // First non-flag argument is the destination
            break
        }

        guard i < args.count else { return nil }
        let destination = args[i]

        // Strip user@ prefix if present
        if let atIndex = destination.lastIndex(of: "@") {
            return String(destination[destination.index(after: atIndex)...])
        }
        return destination
    }
}
