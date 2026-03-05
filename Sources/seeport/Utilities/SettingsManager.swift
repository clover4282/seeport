import Foundation
import Combine

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

    @Published var autoRefreshEnabled: Bool = true
    @Published var refreshInterval: TimeInterval = 5.0
    @Published var showProcessIcons: Bool = true
    @Published var notifyNewPort: Bool = true
    @Published var notifyRemovedPort: Bool = false
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

    private init() {
        let editorRaw = UserDefaults.standard.string(forKey: "seeport.externalEditor") ?? ""
        externalEditor = ExternalEditor(rawValue: editorRaw) ?? .vscode
        let shellRaw = UserDefaults.standard.string(forKey: "seeport.shellApp") ?? ""
        shellApp = ShellApp(rawValue: shellRaw) ?? .iterm
        customEditorPath = UserDefaults.standard.string(forKey: "seeport.customEditorPath") ?? ""
        customEditorArgs = UserDefaults.standard.string(forKey: "seeport.customEditorArgs") ?? ""
        customShellPath = UserDefaults.standard.string(forKey: "seeport.customShellPath") ?? ""
        customShellArgs = UserDefaults.standard.string(forKey: "seeport.customShellArgs") ?? ""
    }

    func resetToDefaults() {
        autoRefreshEnabled = true
        refreshInterval = 5.0
        showProcessIcons = true
        notifyNewPort = true
        notifyRemovedPort = false
        externalEditor = .vscode
        shellApp = .iterm
        customEditorPath = ""
        customEditorArgs = ""
        customShellPath = ""
        customShellArgs = ""
    }
}
