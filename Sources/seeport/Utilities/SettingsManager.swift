import Foundation
import ServiceManagement

enum ExternalEditor: String, CaseIterable {
    case vscode = "Visual Studio Code"
    case cursor = "Cursor"
    case zed = "Zed"
    case sublime = "Sublime Text"
    case webstorm = "WebStorm"
    case intellij = "IntelliJ IDEA"
    case xcode = "Xcode"
    case neovim = "Neovim"
    case custom = "Custom"

    var command: String {
        switch self {
        case .vscode: return "code"
        case .cursor: return "cursor"
        case .zed: return "zed"
        case .sublime: return "subl"
        case .webstorm: return "webstorm"
        case .intellij: return "idea"
        case .xcode: return "xed"
        case .neovim: return "nvim"
        case .custom: return ""
        }
    }
}

enum ShellApp: String, CaseIterable {
    case iterm = "iTerm2"
    case terminal = "Terminal"
    case warp = "Warp"
    case alacritty = "Alacritty"
    case kitty = "Kitty"
    case custom = "Custom"

    var bundleId: String {
        switch self {
        case .iterm: return "com.googlecode.iterm2"
        case .terminal: return "com.apple.Terminal"
        case .warp: return "dev.warp.Warp-Stable"
        case .alacritty: return "org.alacritty"
        case .kitty: return "net.kovidgoyal.kitty"
        case .custom: return ""
        }
    }
}

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var autoRefreshEnabled: Bool = Constants.Defaults.autoRefreshEnabled {
        didSet { UserDefaults.standard.set(autoRefreshEnabled, forKey: "seeport.autoRefreshEnabled") }
    }
    @Published var refreshInterval: TimeInterval = Constants.Defaults.refreshInterval {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "seeport.refreshInterval") }
    }
    @Published var showProcessIcons: Bool = Constants.Defaults.showProcessIcons {
        didSet { UserDefaults.standard.set(showProcessIcons, forKey: "seeport.showProcessIcons") }
    }
    @Published var notifyNewPort: Bool = Constants.Defaults.notifyNewPort {
        didSet { UserDefaults.standard.set(notifyNewPort, forKey: "seeport.notifyNewPort") }
    }
    @Published var notifyRemovedPort: Bool = Constants.Defaults.notifyRemovedPort {
        didSet { UserDefaults.standard.set(notifyRemovedPort, forKey: "seeport.notifyRemovedPort") }
    }
    @Published var notifyLocalPorts: Bool = Constants.Defaults.notifyLocalPorts {
        didSet { UserDefaults.standard.set(notifyLocalPorts, forKey: "seeport.notifyLocalPorts") }
    }
    @Published var notifyDockerPorts: Bool = Constants.Defaults.notifyDockerPorts {
        didSet { UserDefaults.standard.set(notifyDockerPorts, forKey: "seeport.notifyDockerPorts") }
    }
    @Published var notifyAppPorts: Bool = Constants.Defaults.notifyAppPorts {
        didSet { UserDefaults.standard.set(notifyAppPorts, forKey: "seeport.notifyAppPorts") }
    }
    @Published var notifySystemPorts: Bool = Constants.Defaults.notifySystemPorts {
        didSet { UserDefaults.standard.set(notifySystemPorts, forKey: "seeport.notifySystemPorts") }
    }
    @Published var externalEditor: ExternalEditor {
        didSet { UserDefaults.standard.set(externalEditor.rawValue, forKey: "seeport.externalEditor") }
    }
    @Published var shellApp: ShellApp {
        didSet { UserDefaults.standard.set(shellApp.rawValue, forKey: "seeport.shellApp") }
    }
    @Published var customEditorPath: String {
        didSet { UserDefaults.standard.set(customEditorPath, forKey: "seeport.customEditorPath") }
    }
    @Published var customEditorArgs: String {
        didSet { UserDefaults.standard.set(customEditorArgs, forKey: "seeport.customEditorArgs") }
    }
    @Published var customShellPath: String {
        didSet { UserDefaults.standard.set(customShellPath, forKey: "seeport.customShellPath") }
    }
    @Published var customShellArgs: String {
        didSet { UserDefaults.standard.set(customShellArgs, forKey: "seeport.customShellArgs") }
    }
    @Published var launchAtLogin: Bool = true {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Revert on failure so UI stays in sync
                launchAtLogin = !launchAtLogin
            }
        }
    }

    private init() {
        let defaults = UserDefaults.standard

        // Load persisted values (use registered defaults if not set)
        if defaults.object(forKey: "seeport.autoRefreshEnabled") != nil {
            autoRefreshEnabled = defaults.bool(forKey: "seeport.autoRefreshEnabled")
        }
        if defaults.object(forKey: "seeport.refreshInterval") != nil {
            refreshInterval = defaults.double(forKey: "seeport.refreshInterval")
        }
        if defaults.object(forKey: "seeport.showProcessIcons") != nil {
            showProcessIcons = defaults.bool(forKey: "seeport.showProcessIcons")
        }
        if defaults.object(forKey: "seeport.notifyNewPort") != nil {
            notifyNewPort = defaults.bool(forKey: "seeport.notifyNewPort")
        }
        if defaults.object(forKey: "seeport.notifyRemovedPort") != nil {
            notifyRemovedPort = defaults.bool(forKey: "seeport.notifyRemovedPort")
        }
        if defaults.object(forKey: "seeport.notifyLocalPorts") != nil {
            notifyLocalPorts = defaults.bool(forKey: "seeport.notifyLocalPorts")
        }
        if defaults.object(forKey: "seeport.notifyDockerPorts") != nil {
            notifyDockerPorts = defaults.bool(forKey: "seeport.notifyDockerPorts")
        }
        if defaults.object(forKey: "seeport.notifyAppPorts") != nil {
            notifyAppPorts = defaults.bool(forKey: "seeport.notifyAppPorts")
        }
        if defaults.object(forKey: "seeport.notifySystemPorts") != nil {
            notifySystemPorts = defaults.bool(forKey: "seeport.notifySystemPorts")
        }

        let editorRaw = defaults.string(forKey: "seeport.externalEditor") ?? ""
        externalEditor = ExternalEditor(rawValue: editorRaw) ?? Constants.Defaults.externalEditor
        let shellRaw = defaults.string(forKey: "seeport.shellApp") ?? ""
        shellApp = ShellApp(rawValue: shellRaw) ?? Constants.Defaults.shellApp
        customEditorPath = defaults.string(forKey: "seeport.customEditorPath") ?? ""
        customEditorArgs = defaults.string(forKey: "seeport.customEditorArgs") ?? ""
        customShellPath = defaults.string(forKey: "seeport.customShellPath") ?? ""
        customShellArgs = defaults.string(forKey: "seeport.customShellArgs") ?? ""
        let currentStatus = SMAppService.mainApp.status
        if currentStatus == .enabled {
            launchAtLogin = true
        } else if currentStatus == .notRegistered && defaults.object(forKey: "seeport.launchAtLoginSet") == nil {
            // First launch: register by default
            defaults.set(true, forKey: "seeport.launchAtLoginSet")
            try? SMAppService.mainApp.register()
            launchAtLogin = true
        } else {
            launchAtLogin = false
        }
    }

    func resetToDefaults() {
        autoRefreshEnabled = Constants.Defaults.autoRefreshEnabled
        refreshInterval = Constants.Defaults.refreshInterval
        showProcessIcons = Constants.Defaults.showProcessIcons
        notifyNewPort = Constants.Defaults.notifyNewPort
        notifyRemovedPort = Constants.Defaults.notifyRemovedPort
        notifyLocalPorts = Constants.Defaults.notifyLocalPorts
        notifyDockerPorts = Constants.Defaults.notifyDockerPorts
        notifyAppPorts = Constants.Defaults.notifyAppPorts
        notifySystemPorts = Constants.Defaults.notifySystemPorts
        externalEditor = Constants.Defaults.externalEditor
        shellApp = Constants.Defaults.shellApp
        customEditorPath = ""
        customEditorArgs = ""
        customShellPath = ""
        customShellArgs = ""
    }
}
