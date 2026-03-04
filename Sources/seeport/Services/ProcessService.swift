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
        // Fallback: icon from executable path
        let result = ShellExecutor.run("ps -p \(pid) -o comm= 2>/dev/null")
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty {
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

    static func kill(pid: Int32) async -> Bool {
        let result = await ShellExecutor.runAsync("kill -9 \(pid) 2>/dev/null")
        return result.exitCode == 0
    }

    static func getUserForPID(_ pid: Int32) async -> String {
        let result = await ShellExecutor.runAsync("ps -o user= -p \(pid) 2>/dev/null")
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
