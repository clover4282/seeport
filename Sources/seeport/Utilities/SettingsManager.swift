import Foundation
import Combine
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

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var autoRefreshEnabled: Bool = true {
        didSet { UserDefaults.standard.set(autoRefreshEnabled, forKey: "seeport.autoRefreshEnabled") }
    }
    @Published var refreshInterval: TimeInterval = 10.0 {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "seeport.refreshInterval") }
    }
    @Published var showProcessIcons: Bool = true {
        didSet { UserDefaults.standard.set(showProcessIcons, forKey: "seeport.showProcessIcons") }
    }
    @Published var notifyNewPort: Bool = true {
        didSet { UserDefaults.standard.set(notifyNewPort, forKey: "seeport.notifyNewPort") }
    }
    @Published var notifyRemovedPort: Bool = true {
        didSet { UserDefaults.standard.set(notifyRemovedPort, forKey: "seeport.notifyRemovedPort") }
    }
    @Published var notifyLocalPorts: Bool = true {
        didSet { UserDefaults.standard.set(notifyLocalPorts, forKey: "seeport.notifyLocalPorts") }
    }
    @Published var notifyDockerPorts: Bool = true {
        didSet { UserDefaults.standard.set(notifyDockerPorts, forKey: "seeport.notifyDockerPorts") }
    }
    @Published var notifySystemPorts: Bool = false {
        didSet { UserDefaults.standard.set(notifySystemPorts, forKey: "seeport.notifySystemPorts") }
    }
    @Published var notifyOtherPorts: Bool = false {
        didSet { UserDefaults.standard.set(notifyOtherPorts, forKey: "seeport.notifyOtherPorts") }
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
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
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
        if defaults.object(forKey: "seeport.notifySystemPorts") != nil {
            notifySystemPorts = defaults.bool(forKey: "seeport.notifySystemPorts")
        }
        if defaults.object(forKey: "seeport.notifyOtherPorts") != nil {
            notifyOtherPorts = defaults.bool(forKey: "seeport.notifyOtherPorts")
        }

        let editorRaw = defaults.string(forKey: "seeport.externalEditor") ?? ""
        externalEditor = ExternalEditor(rawValue: editorRaw) ?? .vscode
        let shellRaw = defaults.string(forKey: "seeport.shellApp") ?? ""
        shellApp = ShellApp(rawValue: shellRaw) ?? .iterm
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
        autoRefreshEnabled = true
        refreshInterval = 10.0
        showProcessIcons = true
        notifyNewPort = true
        notifyRemovedPort = true
        notifyLocalPorts = true
        notifyDockerPorts = true
        notifySystemPorts = false
        notifyOtherPorts = false
        externalEditor = .vscode
        shellApp = .iterm
        customEditorPath = ""
        customEditorArgs = ""
        customShellPath = ""
        customShellArgs = ""
    }
}
