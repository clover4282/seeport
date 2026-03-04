import SwiftUI
import AppKit

struct PortListView: View {
    let groupedPorts: [(PortCategory, [PortInfo])]
    let processIcons: [Int32: NSImage]
    let onToggleFavorite: (PortInfo) -> Void
    let onKill: (PortInfo) -> Void
    let onMoveToOther: (PortInfo) -> Void
    var onRestore: ((PortInfo) -> Void)?

    var body: some View {
        if groupedPorts.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedPorts, id: \.0) { category, ports in
                        CategoryHeaderView(category: category, count: ports.count)

                        ForEach(ports) { port in
                            PortRowView(
                                port: port,
                                processIcon: processIcons[port.process.pid],
                                onToggleFavorite: { onToggleFavorite(port) },
                                onKill: { onKill(port) },
                                onMoveToOther: { onMoveToOther(port) },
                                onRestore: CategoryOverrides.categoryFor(port.port) != nil ? { onRestore?(port) } : nil
                            )
                        }
                    }
                }
                .padding(.bottom, Constants.Spacing.medium)
            }
        }
    }

    private struct PortGroup {
        let containerName: String?
        let containerImage: String?
        let ports: [PortInfo]
    }

    private func groupByContainer(_ ports: [PortInfo]) -> [PortGroup] {
        var containerGroups: [String: (image: String, ports: [PortInfo])] = [:]
        var standalone: [PortInfo] = []

        for port in ports {
            if let container = port.dockerContainer {
                var group = containerGroups[container.name] ?? (image: container.image, ports: [])
                group.ports.append(port)
                containerGroups[container.name] = group
            } else {
                standalone.append(port)
            }
        }

        var result: [PortGroup] = []

        // Container groups first (only show group wrapper if 2+ ports)
        for (name, group) in containerGroups.sorted(by: { $0.key < $1.key }) {
            if group.ports.count >= 2 {
                result.append(PortGroup(containerName: name, containerImage: group.image, ports: group.ports))
            } else {
                standalone.append(contentsOf: group.ports)
            }
        }

        // Standalone ports
        if !standalone.isEmpty {
            result.append(PortGroup(containerName: nil, containerImage: nil, ports: standalone.sorted { $0.port < $1.port }))
        }

        return result
    }

    private var emptyState: some View {
        VStack(spacing: Constants.Spacing.large) {
            Image(systemName: "network.slash")
                .font(.system(size: 32))
                .foregroundColor(Constants.Colors.textSecondary)

            Text("No ports found")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Constants.Colors.textSecondary)

            Text("No listening TCP ports detected")
                .font(Constants.Fonts.detail)
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

struct ContainerGroupView<Content: View>: View {
    let name: String
    let image: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)
                Text(image)
                    .font(.system(size: 10))
                    .foregroundColor(Constants.Colors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Constants.Spacing.xlarge)
            .padding(.top, Constants.Spacing.medium)
            .padding(.bottom, 2)

            content
        }
        .background(Color.cyan.opacity(0.03))
        .cornerRadius(8)
        .padding(.horizontal, Constants.Spacing.small)
    }
}
