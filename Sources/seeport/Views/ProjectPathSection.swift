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
            HStack(spacing: 6) {
                pathButton(
                    icon: "folder",
                    label: "Finder",
                    color: .gray
                ) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                }

                pathButton(
                    icon: "chevron.left.forwardslash.chevron.right",
                    label: settings.externalEditor.rawValue,
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
                        let cmd = settings.externalEditor.command
                        Task {
                            let process = Process()
                            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                            process.arguments = [cmd, path]
                            try? process.run()
                        }
                    }
                }

                pathButton(
                    icon: "terminal",
                    label: settings.shellApp.rawValue,
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
                        let bundleId = settings.shellApp.bundleId
                        let url = URL(fileURLWithPath: path)
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                            let config = NSWorkspace.OpenConfiguration()
                            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config)
                        }
                    }
                }

                Spacer()
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

    private func pathButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
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
