import SwiftUI
import AppKit

struct PortCardView: View {
    let port: PortInfo
    let processIcon: NSImage?
    let onToggleFavorite: () -> Void
    let onKill: () -> Void

    private let settings = SettingsManager.shared
    @State private var showKillConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: port number + process name + icon
            HStack(spacing: 8) {
                if settings.showProcessIcons, let icon = processIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .cornerRadius(5)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(port.process.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Constants.Colors.textPrimary)
                            .lineLimit(1)
                        portTagBadge
                    }
                    Text("Port \(port.port)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(port.category.color)
                }

                Spacer()

                if port.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                }
            }
            .padding(.bottom, 10)

            // Info section
            infoSection {
                infoRow("PID", value: "\(port.process.pid)")
                infoDivider
                infoRow("User", value: port.process.user)
                infoDivider
                infoRow("Address", value: "\(port.address):\(port.port)")
                infoDivider
                infoRow("Category", value: port.category.rawValue)
            }

            // Project path
            if let projectPath = port.projectPath {
                Spacer().frame(height: 10)

                infoSection {
                    infoRow("Project", value: projectPath)
                }

                // Editor / Shell buttons
                HStack(spacing: 6) {
                    Button(action: {
                        let cmd = settings.externalEditor.command
                        Task {
                            await ShellExecutor.runAsync("\(cmd) \"\(projectPath)\" &")
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "pencil.and.outline")
                                .font(.system(size: 9))
                            Text(settings.externalEditor.rawValue)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .hoverCursor()

                    Button(action: {
                        let bundleId = settings.shellApp.bundleId
                        let url = URL(fileURLWithPath: projectPath)
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                            let config = NSWorkspace.OpenConfiguration()
                            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "terminal")
                                .font(.system(size: 9))
                            Text(settings.shellApp.rawValue)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .hoverCursor()

                    Spacer()
                }
                .padding(.top, 6)
            }

            // Action buttons
            Spacer().frame(height: 10)

            HStack(spacing: 8) {
                cardActionButton(
                    port.isFavorite ? "Unfavorite" : "Favorite",
                    icon: port.isFavorite ? "star.fill" : "star",
                    color: port.isFavorite ? .yellow : .gray
                ) {
                    onToggleFavorite()
                }

                cardActionButton("Open", icon: "safari", color: .blue) {
                    if let url = URL(string: "http://localhost:\(port.port)") {
                        NSWorkspace.shared.open(url)
                    }
                }

                if showKillConfirm {
                    cardActionButton("Confirm", icon: "xmark.circle.fill", color: .red) {
                        onKill()
                        showKillConfirm = false
                    }
                    cardActionButton("Cancel", icon: "arrow.uturn.backward", color: .gray) {
                        showKillConfirm = false
                    }
                } else {
                    cardActionButton("Kill", icon: "xmark.circle", color: .red) {
                        showKillConfirm = true
                    }
                }

                Spacer()
            }
        }
        .padding(Constants.Spacing.large)
        .background(Constants.Colors.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func cardActionButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        ActionButtonView(
            label: label,
            icon: icon,
            color: color,
            isLoading: false,
            isDisabled: false,
            action: action
        )
    }

    private var portTagBadge: some View {
        let tag = CategoryEngine.portTag(port: port.port, dockerImage: port.dockerContainer?.image)
        let color: Color = {
            switch tag {
            case "Frontend": return .blue
            case "Backend": return .green
            case "Database": return .orange
            default: return .gray
            }
        }()
        return Text(tag)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }

    private func infoSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Constants.Colors.textPrimary)
            Spacer()
            CopyableValueText(value: value)
        }
        .padding(.horizontal, Constants.Spacing.medium)
        .padding(.vertical, 6)
    }

    private var infoDivider: some View {
        Divider()
            .background(Color.white.opacity(0.06))
            .padding(.horizontal, Constants.Spacing.medium)
    }
}
