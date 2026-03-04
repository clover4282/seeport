import Foundation

struct DockerContainer: Identifiable, Hashable {
    let id: String
    let name: String
    let image: String
    let status: String
    let ports: [PortMapping]

    struct PortMapping: Hashable {
        let hostPort: UInt16
        let containerPort: UInt16
        let proto: String

        // Tag is set externally based on container image
        var tag: String = "Service"
    }
}

extension PortCategory {
    var portTag: String {
        switch self {
        case .frontend: return "Frontend"
        case .backend: return "Backend"
        case .database: return "Database"
        case .docker: return "Service"
        case .system: return "System"
        case .other: return "Service"
        }
    }

    var tagColor: (r: Double, g: Double, b: Double) {
        switch self {
        case .frontend: return (0.2, 0.5, 1.0)
        case .backend: return (0.1, 0.8, 0.4)
        case .database: return (1.0, 0.6, 0.0)
        case .docker: return (0.0, 0.8, 1.0)
        case .system: return (0.5, 0.5, 0.5)
        case .other: return (0.6, 0.6, 0.6)
        }
    }
}
