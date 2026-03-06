import Foundation
import AppKit

enum BrowserLauncher {
    static let defaultScheme = "http"

    static func open(address: String, port: UInt16, scheme: String = defaultScheme) {
        guard let url = url(address: address, port: port, scheme: scheme) else { return }
        NSWorkspace.shared.open(url)
    }

    static func url(address: String, port: UInt16, scheme: String = defaultScheme) -> URL? {
        let resolvedHost = resolvedHost(for: address)
        guard !resolvedHost.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = resolvedHost
        components.port = Int(port)
        return components.url
    }

    static func urlString(address: String, port: UInt16, scheme: String = defaultScheme) -> String? {
        url(address: address, port: port, scheme: scheme)?.absoluteString
    }

    static func label(address: String, port: UInt16) -> String {
        "\(displayHost(for: address)):\(port)"
    }

    static func displayHost(for address: String) -> String {
        let normalized = normalizedAddress(address)
        switch normalized {
        case "", "0.0.0.0", "::", "::0", "127.0.0.1", "::1":
            return "localhost"
        default:
            return normalized
        }
    }

    private static func resolvedHost(for address: String) -> String {
        let normalized = normalizedAddress(address)
        switch normalized {
        case "", "0.0.0.0", "::", "::0":
            return "localhost"
        default:
            return normalized
        }
    }

    private static func normalizedAddress(_ address: String) -> String {
        var normalized = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("[") && normalized.hasSuffix("]") {
            normalized.removeFirst()
            normalized.removeLast()
        }
        return normalized
    }
}
