import Foundation
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var autoRefreshEnabled: Bool = true
    @Published var refreshInterval: TimeInterval = 5.0
    @Published var showProcessIcons: Bool = true

    private init() {}

    func resetToDefaults() {
        autoRefreshEnabled = true
        refreshInterval = 5.0
        showProcessIcons = true
    }
}
