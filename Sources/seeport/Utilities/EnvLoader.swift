import Foundation

enum EnvLoader {
    private static var values: [String: String] = {
        load()
    }()

    static func get(_ key: String, fallback: String = "") -> String {
        // 1. Check process environment (e.g. from Xcode scheme or shell)
        if let val = Foundation.ProcessInfo.processInfo.environment[key], !val.isEmpty {
            return val
        }
        // 2. Check .env file
        if let val = values[key], !val.isEmpty {
            return val
        }
        return fallback
    }

    private static func load() -> [String: String] {
        // Look for .env relative to the executable, then working directory
        let candidates = [
            Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".env"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env"),
            URL(fileURLWithPath: #filePath) // source dir fallback
                .deletingLastPathComponent() // Utilities/
                .deletingLastPathComponent() // seeport/
                .deletingLastPathComponent() // Sources/
                .deletingLastPathComponent() // project root
                .appendingPathComponent(".env")
        ]

        for url in candidates {
            if let contents = try? String(contentsOf: url, encoding: .utf8) {
                return parse(contents)
            }
        }
        return [:]
    }

    private static func parse(_ contents: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            // Strip quotes
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value
        }
        return result
    }
}
