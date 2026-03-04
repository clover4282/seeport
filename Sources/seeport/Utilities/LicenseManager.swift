import Foundation

enum LicenseStatus: Equatable {
    case trial(daysRemaining: Int)
    case active(licenseKey: String)
    case expired

    static func == (lhs: LicenseStatus, rhs: LicenseStatus) -> Bool {
        switch (lhs, rhs) {
        case (.trial(let a), .trial(let b)): return a == b
        case (.active(let a), .active(let b)): return a == b
        case (.expired, .expired): return true
        default: return false
        }
    }
}

@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let firstLaunch = "seeport.firstLaunchDate"
        static let licenseKey = "seeport.licenseKey"
        static let licenseActive = "seeport.licenseActive"
        static let activatedDate = "seeport.activatedDate"
    }

    static let trialDays = 30

    @Published var status: LicenseStatus
    @Published var isActivating = false
    @Published var activationError: String?

    private init() {
        if defaults.object(forKey: Keys.firstLaunch) == nil {
            defaults.set(Date(), forKey: Keys.firstLaunch)
        }

        if let key = defaults.string(forKey: Keys.licenseKey),
           defaults.bool(forKey: Keys.licenseActive) {
            status = .active(licenseKey: key)
        } else {
            let firstLaunch = defaults.object(forKey: Keys.firstLaunch) as? Date ?? Date()
            let daysSince = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
            let remaining = max(0, Self.trialDays - daysSince)
            if remaining > 0 {
                status = .trial(daysRemaining: remaining)
            } else {
                status = .expired
            }
        }
    }

    var firstLaunchDate: Date {
        defaults.object(forKey: Keys.firstLaunch) as? Date ?? Date()
    }

    var trialEndDate: Date {
        Calendar.current.date(byAdding: .day, value: Self.trialDays, to: firstLaunchDate) ?? Date()
    }

    var activatedDate: Date? {
        defaults.object(forKey: Keys.activatedDate) as? Date
    }

    var maskedKey: String {
        if case .active(let key) = status {
            guard key.count > 8 else { return key }
            let prefix = String(key.prefix(4))
            let suffix = String(key.suffix(4))
            return "\(prefix)-****-****-\(suffix)"
        }
        return ""
    }

    func activate(key: String) async {
        guard !key.isEmpty else {
            activationError = "Please enter a license key"
            return
        }

        isActivating = true
        activationError = nil

        let result = await PaddleService.activate(licenseKey: key)

        switch result {
        case .success(let validatedKey):
            defaults.set(validatedKey, forKey: Keys.licenseKey)
            defaults.set(true, forKey: Keys.licenseActive)
            defaults.set(Date(), forKey: Keys.activatedDate)
            status = .active(licenseKey: validatedKey)
            activationError = nil

        case .failure(let error):
            activationError = error.localizedDescription
        }

        isActivating = false
    }

    func deactivate() {
        defaults.removeObject(forKey: Keys.licenseKey)
        defaults.set(false, forKey: Keys.licenseActive)
        defaults.removeObject(forKey: Keys.activatedDate)

        let firstLaunch = defaults.object(forKey: Keys.firstLaunch) as? Date ?? Date()
        let daysSince = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
        let remaining = max(0, Self.trialDays - daysSince)
        if remaining > 0 {
            status = .trial(daysRemaining: remaining)
        } else {
            status = .expired
        }
    }

    /// Periodically verify the license is still valid
    func verifyIfNeeded() async {
        guard case .active(let key) = status else { return }
        let result = await PaddleService.verify(licenseKey: key)
        if case .success(false) = result {
            deactivate()
        }
    }
}
