import Foundation

enum Favorites {
    private static let key = "seeport.favorites"

    static func load() -> Set<UInt16> {
        let array = UserDefaults.standard.array(forKey: key) as? [UInt16] ?? []
        return Set(array)
    }

    static func save(_ favorites: Set<UInt16>) {
        UserDefaults.standard.set(Array(favorites), forKey: key)
    }

    static func toggle(_ port: UInt16) -> Bool {
        var favs = load()
        if favs.contains(port) {
            favs.remove(port)
        } else {
            favs.insert(port)
        }
        save(favs)
        return favs.contains(port)
    }

    static func isFavorite(_ port: UInt16) -> Bool {
        load().contains(port)
    }
}
