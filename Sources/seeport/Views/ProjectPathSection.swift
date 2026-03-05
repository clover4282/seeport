import SwiftUI

struct ProjectPathSection: View {
    let path: String
    private let settings = SettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Path row
            HStack {
                Text("PATH")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Constants.Colors.textSecondary.opacity(0.7))
                    .tracking(1)
                CopyableValueText(value: path)
                Spacer()
            }
            .padding(.horizontal, Constants.Spacing.medium)
            .padding(.vertical, 6)

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, Constants.Spacing.medium)

            // Action buttons
            HStack(spacing: 4) {
                pathButton(
                    icon: "folder",
                    label: "Finder",
                    color: .gray
                ) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                }

                pathButton(
                    icon: "chevron.left.forwardslash.chevron.right",
                    label: editorShortName,
                    color: .blue
                ) {
                    if settings.externalEditor == .custom {
                        let editorPath = settings.customEditorPath
                        guard !editorPath.isEmpty else { return }
                        let args: [String]
                        if settings.customEditorArgs.isEmpty {
                            args = [path]
                        } else {
                            args = settings.customEditorArgs
                                .replacingOccurrences(of: "%TARGET_PATH%", with: path)
                                .components(separatedBy: " ")
                        }
                        Task {
                            let process = Process()
                            process.executableURL = URL(fileURLWithPath: editorPath)
                            process.arguments = args
                            try? process.run()
                        }
                    } else {
                        // Use `open -a` to avoid PATH issues in GUI app context
                        let appName = settings.externalEditor.rawValue
                        Task {
                            let process = Process()
                            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                            process.arguments = ["-a", appName, path]
                            try? process.run()
                        }
                    }
                }

                pathButton(
                    icon: "terminal",
                    label: shellShortName,
                    color: .green
                ) {
                    if settings.shellApp == .custom {
                        let shellPath = settings.customShellPath
                        guard !shellPath.isEmpty else { return }
                        let args: [String]
                        if settings.customShellArgs.isEmpty {
                            args = [path]
                        } else {
                            args = settings.customShellArgs
                                .replacingOccurrences(of: "%TARGET_PATH%", with: path)
                                .components(separatedBy: " ")
                        }
                        Task {
                            let process = Process()
                            process.executableURL = URL(fileURLWithPath: shellPath)
                            process.arguments = args
                            process.currentDirectoryURL = URL(fileURLWithPath: path)
                            try? process.run()
                        }
                    } else {
                        openShellNewWindow(app: settings.shellApp, path: path)
                    }
                }

            }
            .padding(.horizontal, Constants.Spacing.medium)
            .padding(.vertical, 6)
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var editorShortName: String {
        switch settings.externalEditor {
        case .vscode: return "VS Code"
        case .cursor: return "Cursor"
        case .zed: return "Zed"
        case .sublime: return "Sublime"
        case .webstorm: return "WebStorm"
        case .intellij: return "IntelliJ"
        case .xcode: return "Xcode"
        case .neovim: return "Neovim"
        case .custom:
            let name = URL(fileURLWithPath: settings.customEditorPath).deletingPathExtension().lastPathComponent
            return name.isEmpty ? "Editor" : name
        }
    }

    private var shellShortName: String {
        switch settings.shellApp {
        case .iterm: return "iTerm"
        case .terminal: return "Terminal"
        case .warp: return "Warp"
        case .alacritty: return "Alacritty"
        case .kitty: return "Kitty"
        case .custom:
            let name = URL(fileURLWithPath: settings.customShellPath).deletingPathExtension().lastPathComponent
            return name.isEmpty ? "Shell" : name
        }
    }

    private func openShellNewWindow(app: ShellApp, path: String) {
        let escapedPath = path.replacingOccurrences(of: "'", with: "'\\''")
        let script: String
        switch app {
        case .iterm:
            script = """
            tell application "iTerm2"
                activate
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "cd '\(escapedPath)'"
                end tell
            end tell
            """
        case .terminal:
            script = """
            tell application "Terminal"
                activate
                do script "cd '\(escapedPath)'"
            end tell
            """
        default:
            // For other shells, use open -a with new instance
            Task {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                process.arguments = ["-n", "-a", app.rawValue, path]
                try? process.run()
            }
            return
        }
        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        }
    }

    private func pathButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .hoverCursor()
    }
}
