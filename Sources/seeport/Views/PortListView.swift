import SwiftUI
import AppKit

struct PortListView: View {
    let groupedPorts: [(PortCategory, [PortInfo])]
    let processIcons: [Int32: NSImage]
    let onToggleFavorite: (PortInfo) -> Void
    let onKill: (PortInfo) -> Void
    let onMoveToSystem: (PortInfo) -> Void
    var onRestore: ((PortInfo) -> Void)?

    var body: some View {
        if groupedPorts.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedPorts, id: \.0) { category, ports in
                        CategoryHeaderView(category: category, count: ports.count)

                        ForEach(clusters(ports), id: \.key) { cluster in
                            clusterRow(cluster)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(cluster.ports[0].category.color.opacity(0.5))
                                        .frame(width: 3)
                                        .padding(.vertical, 8)
                                        .padding(.leading, 7)
                                }
                        }
                    }
                }
                .padding(.bottom, Constants.Spacing.medium)
            }
        }
    }

    @ViewBuilder
    private func clusterRow(_ cluster: (key: String, ports: [PortInfo])) -> some View {
        if cluster.ports.count == 1 {
            let port = cluster.ports[0]
            PortRowView(
                port: port,
                processIcon: processIcons[port.process.pid],
                onToggleFavorite: { onToggleFavorite(port) },
                onKill: { onKill(port) },
                onMoveToSystem: { onMoveToSystem(port) },
                onRestore: CategoryOverrides.categoryFor(port.port) != nil ? { onRestore?(port) } : nil
            )
        } else {
            PortClusterView(
                ports: cluster.ports,
                processIcons: processIcons,
                onToggleFavorite: onToggleFavorite,
                onKill: onKill,
                onMoveToSystem: onMoveToSystem,
                onRestore: onRestore
            )
        }
    }

    /// Groups ports that share an owner (same Docker container, or same process
    /// PID for local/app ports) so a multi-port owner renders as one entry.
    /// First-appearance order is preserved; ports within a cluster are sorted.
    private func clusters(_ ports: [PortInfo]) -> [(key: String, ports: [PortInfo])] {
        var order: [String] = []
        var map: [String: [PortInfo]] = [:]
        for port in ports {
            let key = port.dockerContainer.map { "docker:\($0.id)" } ?? "pid:\(port.process.pid)"
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(port)
        }
        return order.map { key in (key, map[key]!.sorted { $0.port < $1.port }) }
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
