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

    private static func getExecutablePath(pid: Int32) -> String? {
        let maxPathSize = 4 * Int(MAXPATHLEN)
        var pathBuffer = [CChar](repeating: 0, count: maxPathSize)
        let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(maxPathSize))
        guard pathLen > 0 else { return nil }
        return String(cString: pathBuffer)
    }

    static func getWorkingDirectory(pid: Int32) async -> String? {
        let result = await ShellExecutor.runAsync("lsof -a -d cwd -p \(pid) -F n 2>/dev/null")
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
        let result = await ShellExecutor.runAsync("kill -9 \(pid) 2>/dev/null")
        return result.exitCode == 0
    }

    static func getUserForPID(_ pid: Int32) async -> String {
        let result = await ShellExecutor.runAsync("ps -o user= -p \(pid) 2>/dev/null")
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
