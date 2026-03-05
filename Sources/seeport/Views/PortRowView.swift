import SwiftUI

struct PortRowView: View {
    let port: PortInfo
    let processIcon: NSImage?
    let onToggleFavorite: () -> Void
    let onKill: () -> Void
    let onMoveToOther: () -> Void
    var onRestore: (() -> Void)?

    private let settings = SettingsManager.shared
    @State private var isHovering = false
    @State private var isPortHovering = false
    @State private var showPopover = false
    @State private var showKillConfirm = false

    var body: some View {
        HStack(spacing: Constants.Spacing.large) {
            // Port number (click to open in browser)
            let isManualOverride = CategoryOverrides.categoryFor(port.port) != nil
            let baseColor = isManualOverride ? Color.purple : port.category.color
            Text(String(port.port))
                .font(Constants.Fonts.portNumber)
                .foregroundColor(isPortHovering ? baseColor.opacity(0.6) : baseColor)
                .underline(isPortHovering)
                .frame(width: 80, alignment: .leading)
                .minimumScaleFactor(0.8)
                .onTapGesture {
                    if let url = URL(string: "http://localhost:\(port.port)") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .onHover { hovering in
                    isPortHovering = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            // Process icon
            if settings.showProcessIcons, let icon = processIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(5)
            }

            // Process info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Constants.Spacing.small) {
                    if let container = port.dockerContainer {
                        Text(container.name)
                            .font(Constants.Fonts.processName)
                            .foregroundColor(Constants.Colors.textPrimary)
                            .lineLimit(1)
                        portTagBadge
                    } else {
                        Text(port.process.name)
                            .font(Constants.Fonts.processName)
                            .foregroundColor(Constants.Colors.textPrimary)
                            .lineLimit(1)
                        portTagBadge
                    }
                }

                if let container = port.dockerContainer {
                    HStack(spacing: Constants.Spacing.medium) {
                        Label(container.image, systemImage: "shippingbox")
                        Text("·")
                        Text(String(container.id.prefix(8)))
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .font(Constants.Fonts.detail)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .lineLimit(1)
                } else {
                    HStack(spacing: Constants.Spacing.medium) {
                        Label("PID: \(port.process.pid)", systemImage: "number")
                        Label(port.process.user, systemImage: "person")
                    }
                    .font(Constants.Fonts.detail)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .lineLimit(1)
                }
            }

            Spacer()

            // Favorite toggle (always visible)
            Button(action: {
                onToggleFavorite()
            }) {
                Image(systemName: port.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundColor(port.isFavorite ? .yellow : Constants.Colors.textSecondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .hoverCursor()
        }
        .padding(.horizontal, Constants.Spacing.xlarge)
        .padding(.vertical, Constants.Spacing.medium)
        .background(isHovering ? Constants.Colors.cardBackground : Color.clear)
        .cornerRadius(6)
        .onTapGesture {
            showPopover.toggle()
        }
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            portDetailPopover
        }
        .onChange(of: showPopover) { newValue in
            if !newValue { showKillConfirm = false }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(color == .gray ? Constants.Colors.textSecondary : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverCursor()
    }

    private func detailSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(Constants.Colors.textSecondary.opacity(0.7))
            .tracking(1)
            .padding(.top, 2)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Constants.Colors.textSecondary)
                .frame(width: 70, alignment: .trailing)
            CopyableValueText(value: value)
            Spacer()
        }
    }

    private var portDetailPopover: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            // Header with open button
            HStack {
                if let icon = processIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                }
                Text("Port " + String(port.port))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Constants.Colors.textPrimary)
                Spacer()
                Button(action: {
                    if let url = URL(string: "http://localhost:\(port.port)") {
                        NSWorkspace.shared.open(url)
                    }
                    showPopover = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "safari")
                            .font(.system(size: 11))
                        Text("Open")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .hoverCursor()
            }

            Divider().background(Color.white.opacity(0.1))

            // Detail info
            if let container = port.dockerContainer {
                detailSectionHeader("Container")
                detailRow("Name", container.name)
                detailRow("Image", container.image)
                detailRow("ID", String(container.id.prefix(12)))
                detailRow("Status", container.status)

                Divider().background(Color.white.opacity(0.06))

                detailSectionHeader("Network")
                detailRow("Address", port.address + ":" + String(port.port))
                detailRow("Protocol", "TCP")
                if !container.ports.isEmpty {
                    ForEach(Array(container.ports.enumerated()), id: \.offset) { _, mapping in
                        detailRow("Mapping", "\(mapping.hostPort) → \(mapping.containerPort)/\(mapping.proto)")
                    }
                }

                Divider().background(Color.white.opacity(0.06))

                detailSectionHeader("Classification")
                detailRow("Category", port.category.rawValue)
                let tag = CategoryEngine.portTag(port: port.port, dockerImage: container.image)
                detailRow("Tag", tag)

                if let projectPath = port.projectPath {
                    Divider().background(Color.white.opacity(0.06))
                    ProjectPathSection(path: projectPath)
                        .padding(.top, 4)
                }
            } else {
                detailSectionHeader("Process")
                detailRow("Name", port.process.name)
                detailRow("PID", "\(port.process.pid)")
                detailRow("User", port.process.user)

                Divider().background(Color.white.opacity(0.06))

                detailSectionHeader("Network")
                detailRow("Address", port.address + ":" + String(port.port))
                detailRow("Protocol", "TCP")

                Divider().background(Color.white.opacity(0.06))

                detailSectionHeader("Classification")
                detailRow("Category", port.category.rawValue)
                let tag = CategoryEngine.portTag(port: port.port, dockerImage: nil)
                detailRow("Tag", tag)

                if let projectPath = port.projectPath {
                    Divider().background(Color.white.opacity(0.06))
                    ProjectPathSection(path: projectPath)
                        .padding(.top, 4)
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Action buttons
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Favorite
                    actionButton(
                        icon: port.isFavorite ? "star.fill" : "star",
                        label: port.isFavorite ? "Unfavorite" : "Favorite",
                        color: port.isFavorite ? .yellow : .gray
                    ) {
                        onToggleFavorite()
                        showPopover = false
                    }

                    // Move to Other / Restore
                    if port.category == .docker || port.category == .backend {
                        actionButton(
                            icon: "arrow.right.square",
                            label: "Move to Other",
                            color: .gray
                        ) {
                            onMoveToOther()
                            showPopover = false
                        }
                    } else if let onRestore = onRestore {
                        actionButton(
                            icon: "arrow.uturn.backward",
                            label: "Restore",
                            color: .green
                        ) {
                            onRestore()
                            showPopover = false
                        }
                    }
                }

                // Kill button (Docker / Local Server only)
                if port.category == .docker || port.category == .backend {
                    if showKillConfirm {
                        HStack(spacing: 0) {
                            Text("Terminate this process?")
                                .font(.system(size: 11))
                                .foregroundColor(Constants.Colors.textSecondary)
                            Spacer()
                            Button(action: { showKillConfirm = false }) {
                                Text("Cancel")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Constants.Colors.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .hoverCursor()
                            .padding(.trailing, 8)
                            Button(action: {
                                onKill()
                                showPopover = false
                                showKillConfirm = false
                            }) {
                                Text("Kill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Constants.Colors.danger)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .hoverCursor()
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(8)
                    } else {
                        Button(action: { showKillConfirm = true }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                Text("Kill Process")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(Constants.Colors.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .hoverCursor()
                    }
                }
            }
        }
        .padding(Constants.Spacing.large)
        .frame(width: 280)
        .background(Constants.Colors.background)
    }

    private var dockerBadge: some View {
        Text("Docker")
            .font(Constants.Fonts.badge)
            .foregroundColor(.cyan)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.cyan.opacity(0.15))
            .cornerRadius(4)
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
            .font(Constants.Fonts.badge)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

struct CopyableValueText: View {
    let value: String
    @State private var isHovering = false
    @State private var showCopied = false

    var body: some View {
        Text(showCopied ? "Copied!" : value)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(showCopied ? .green : (isHovering ? .blue : Constants.Colors.textPrimary))
            .underline(isHovering && !showCopied)
            .lineLimit(1)
            .onHover { hovering in
                isHovering = hovering
                if hovering { NSCursor.pointingHand.push() }
                else { NSCursor.pop() }
            }
            .onTapGesture {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    showCopied = false
                }
            }
    }
}
