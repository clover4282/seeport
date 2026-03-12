import SwiftUI

enum PortCategory: String, CaseIterable, Identifiable {
    case favorites = "FAVORITES"
    case frontend = "FRONTEND"
    case backend = "LOCAL SERVER"
    case database = "DATABASE"
    case docker = "DOCKER"
    case system = "SYSTEM"
    case other = "OTHER"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .favorites: return "star.fill"
        case .frontend: return "globe"
        case .backend: return "server.rack"
        case .database: return "cylinder"
        case .docker: return "shippingbox"
        case .system: return "gearshape"
        case .other: return "ellipsis.circle"
        }
    }

    var color: Color {
        switch self {
        case .favorites: return .yellow
        case .frontend: return .blue
        case .backend: return .green
        case .database: return .orange
        case .docker: return .cyan
        case .system: return .gray
        case .other: return .secondary
        }
    }
}
