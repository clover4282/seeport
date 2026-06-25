import Foundation

enum CategoryOverrides {
    private static let key = "seeport.categoryOverrides"
    private static var cache: [UInt16: String]?

    static func load() -> [UInt16: String] {
        if let cache { return cache }
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        var result: [UInt16: String] = [:]
        for (k, v) in dict {
            if let port = UInt16(k) {
                result[port] = v
            }
        }
        cache = result
        return result
    }

    private static func save(_ overrides: [UInt16: String]) {
        cache = overrides
        var dict: [String: String] = [:]
        for (k, v) in overrides {
            dict[String(k)] = v
        }
        UserDefaults.standard.set(dict, forKey: key)
    }

    static func setSystem(_ port: UInt16) {
        var overrides = load()
        overrides[port] = PortCategory.system.rawValue
        save(overrides)
    }

    static func remove(_ port: UInt16) {
        var overrides = load()
        overrides.removeValue(forKey: port)
        save(overrides)
    }

    static func categoryFor(_ port: UInt16) -> PortCategory? {
        guard let raw = load()[port] else { return nil }
        return PortCategory(rawValue: raw)
    }
}
