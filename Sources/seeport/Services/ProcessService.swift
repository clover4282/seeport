import Foundation
import AppKit

enum ProcessService {
    static func iconOrNil(for pid: Int32) -> NSImage? {
        if let app = NSRunningApplication(processIdentifier: pid), let appIcon = app.icon {
            return appIcon
        }
        return nil
    }

    static func icon(for pid: Int32) -> NSImage {
        // Try running app icon first
        if let app = NSRunningApplication(processIdentifier: pid), let appIcon = app.icon {
            return appIcon
        }
        // Fallback: use proc_pidpath (no shell fork)
        let path = getExecutablePath(pid: pid)
        if let path, !path.isEmpty {
            // Walk up to find .app bundle
            var url = URL(fileURLWithPath: path)
            for _ in 0..<5 {
                url = url.deletingLastPathComponent()
                if url.pathExtension == "app" {
                    return NSWorkspace.shared.icon(forFile: url.path)
                }
            }
            return NSWorkspace.shared.icon(forFile: path)
        }
        return NSWorkspace.shared.icon(forFile: "/usr/bin/env")
    }

    /// Load icon off the main thread, returning nil if unavailable.
    static func loadIconAsync(for pid: Int32) async -> NSImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let img = icon(for: pid)
                continuation.resume(returning: img)
            }
        }
    }

    private static func getExecutablePath(pid: Int32) -> String? {
        let maxPathSize = 4 * Int(MAXPATHLEN)
        var pathBuffer = [CChar](repeating: 0, count: maxPathSize)
        let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(maxPathSize))
        guard pathLen > 0 else { return nil }
        return String(cString: pathBuffer)
    }

    static func getWorkingDirectory(pid: Int32) async -> String? {
        let result = await ShellExecutor.runDirectAsync(
            "/usr/bin/lsof", arguments: ["-a", "-d", "cwd", "-p", "\(pid)", "-F", "n"]
        )
        guard result.exitCode == 0 else { return nil }
        for line in result.output.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("n/") {
                let path = String(s.dropFirst(1))
                // Skip home directory itself and root
                if path == "/" || path == NSHomeDirectory() { return nil }
                return path
            }
        }
        return nil
    }

    static func kill(pid: Int32) async -> Bool {
        Darwin.kill(pid, SIGKILL) == 0
    }

    static func getUserForPID(_ pid: Int32) async -> String {
        let result = await ShellExecutor.runDirectAsync(
            "/bin/ps", arguments: ["-o", "user=", "-p", "\(pid)"]
        )
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
