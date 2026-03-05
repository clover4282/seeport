import SwiftUI

struct ContainerCardView: View {
    let container: DockerContainer
    var onAction: ((String, String) async -> Void)?

    @State private var loadingAction: String?

    private var isRunning: Bool {
        container.status.lowercased().hasPrefix("up")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Container info section
            infoSection {
                infoRow("Name", value: container.name)
                infoDivider
                infoRow("ID", value: container.id)
                infoDivider
                infoRow("Image", value: container.image)
                infoDivider
                infoRow("Status", value: container.status)
            }

            // Project path
            if let projectPath = container.projectPath {
                Spacer().frame(height: 10)

                infoSection {
                    infoRow("Project", value: projectPath)
                }
            }

            // Port Forwards
            if !container.ports.isEmpty {
                Spacer().frame(height: 10)

                infoSection {
                    // Header
                    HStack {
                        Text("Host Port")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Container Port")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Protocol")
                            .frame(width: 60, alignment: .leading)
                        Text("Type")
                            .frame(width: 70, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Constants.Colors.textSecondary)
                    .padding(.horizontal, Constants.Spacing.medium)
                    .padding(.vertical, 4)

                    ForEach(Array(container.ports.enumerated()), id: \.offset) { index, mapping in
                        if index > 0 { infoDivider }
                        portRow(mapping)
                    }
                }
            }

            // Action buttons
            Spacer().frame(height: 10)

            HStack(spacing: 8) {
                if isRunning {
                    actionButton("Stop", icon: "stop.fill", color: .red, action: "stop")
                    actionButton("Restart", icon: "arrow.clockwise", color: .blue, action: "restart")
                } else {
                    actionButton("Start", icon: "play.fill", color: .green, action: "start")
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

    private func actionButton(_ label: String, icon: String, color: Color, action: String) -> some View {
        ActionButtonView(
            label: label,
            icon: icon,
            color: color,
            isLoading: loadingAction == action,
            isDisabled: loadingAction != nil
        ) {
            guard loadingAction == nil else { return }
            loadingAction = action
            Task {
                await onAction?(action, container.id)
                loadingAction = nil
            }
        }
    }

    private func portRow(_ mapping: DockerContainer.PortMapping) -> some View {
        PortRowCell(mapping: mapping)
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

private struct PortRowCell: View {
    let mapping: DockerContainer.PortMapping
    @State private var isHovering = false

    var body: some View {
        HStack {
            Text(String(mapping.hostPort))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(isHovering ? .cyan.opacity(0.6) : .cyan)
                .underline(isHovering)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture {
                    if let url = URL(string: "http://localhost:\(mapping.hostPort)") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .onHover { hovering in
                    isHovering = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }

            CopyableValueText(value: String(mapping.containerPort))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(mapping.proto.uppercased())
                .font(.system(size: 12))
                .foregroundColor(Constants.Colors.textSecondary)
                .frame(width: 60, alignment: .leading)

            portTag(mapping.tag)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, Constants.Spacing.medium)
        .padding(.vertical, 4)
    }

    private func portTag(_ tag: String) -> some View {
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
}

struct ActionButtonView: View {
    let label: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isLoading ? Constants.Colors.textSecondary : (isHovering ? color.opacity(0.7) : color))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(isLoading ? 0.05 : (isHovering ? 0.22 : 0.12)))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(isHovering ? 0.35 : 0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
