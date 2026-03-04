import Foundation

struct PortInfo: Identifiable, Hashable {
    let id: String
    let port: UInt16
    let process: ProcessInfo
    let category: PortCategory
    let address: String
    var isFavorite: Bool
    var dockerContainer: DockerContainer?

    init(
        port: UInt16,
        process: ProcessInfo,
        category: PortCategory = .other,
        address: String = "127.0.0.1",
        isFavorite: Bool = false,
        dockerContainer: DockerContainer? = nil
    ) {
        self.id = "\(port)-\(process.pid)"
        self.port = port
        self.process = process
        self.category = category
        self.address = address
        self.isFavorite = isFavorite
        self.dockerContainer = dockerContainer
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(port)
        hasher.combine(process.pid)
    }

    static func == (lhs: PortInfo, rhs: PortInfo) -> Bool {
        lhs.port == rhs.port && lhs.process.pid == rhs.process.pid
    }
}
