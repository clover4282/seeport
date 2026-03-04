import SwiftUI

enum Constants {
    static let popoverWidth: CGFloat = 420
    static let popoverHeight: CGFloat = 600
    static let defaultRefreshInterval: TimeInterval = 5.0
    static let menuBarIcon = "network"

    enum Colors {
        static let background = Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0))
        static let cardBackground = Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0))
        static let searchBackground = Color(nsColor: NSColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0))
        static let accent = Color.blue
        static let textPrimary = Color.white
        static let textSecondary = Color.gray
        static let statusGreen = Color.green
        static let danger = Color.red
    }

    enum Fonts {
        static let portNumber = Font.system(size: 18, weight: .bold, design: .monospaced)
        static let processName = Font.system(size: 13, weight: .medium)
        static let detail = Font.system(size: 11)
        static let badge = Font.system(size: 10, weight: .medium)
        static let sectionHeader = Font.system(size: 12, weight: .semibold)
    }

    enum Spacing {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
    }
}
