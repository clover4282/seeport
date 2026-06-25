import SwiftUI

enum PortCategory: String, CaseIterable, Identifiable {
    case favorites = "FAVORITES"
    case local = "LOCAL"
    case docker = "DOCKER"
    case app = "APP"
    case system = "SYSTEM"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .favorites: return "star.fill"
        case .local: return "server.rack"
        case .docker: return "shippingbox"
        case .app: return "macwindow"
        case .system: return "gearshape"
        }
    }

    var color: Color {
        switch self {
        case .favorites: return .yellow
        case .local: return .blue
        case .docker: return .cyan
        case .app: return .purple
        case .system: return .gray
        }
    }
}
