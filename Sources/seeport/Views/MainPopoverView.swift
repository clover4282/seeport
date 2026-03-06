import SwiftUI

struct MainPopoverView: View {
    @StateObject private var viewModel = PortListViewModel()

    var body: some View {
        mainContent
            .frame(width: Constants.popoverWidth, height: Constants.popoverHeight)
            .background(Constants.Colors.background)
            .onAppear {
                viewModel.setPopoverVisible(true)
            }
            .onDisappear {
                viewModel.setPopoverVisible(false)
            }
    }

    private var dockerContainerList: some View {
        let query = viewModel.searchText.lowercased()
        let containers = viewModel.dockerContainers.filter { c in
            query.isEmpty ||
            c.name.lowercased().contains(query) ||
            c.image.lowercased().contains(query) ||
            c.id.lowercased().contains(query) ||
            c.ports.contains { String($0.hostPort).contains(query) }
        }

        return Group {
            if containers.isEmpty {
                VStack(spacing: Constants.Spacing.large) {
                    Image(systemName: "shippingbox.slash")
                        .font(.system(size: 32))
                        .foregroundColor(Constants.Colors.textSecondary)
                    Text("No Docker containers")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Constants.Spacing.medium) {
                        ForEach(containers) { container in
                            ContainerCardView(container: container) { action, containerId in
                                await viewModel.dockerAction(action, containerId: containerId)
                            }
                        }
                    }
                }
            }
        }
    }

    private var portCardList: some View {
        let ports = viewModel.filteredPorts
        return Group {
            if ports.isEmpty {
                VStack(spacing: Constants.Spacing.large) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 32))
                        .foregroundColor(Constants.Colors.textSecondary)
                    Text(viewModel.selectedTab == .favorites ? "No favorites" : "No local servers")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Constants.Spacing.medium) {
                        ForEach(ports) { port in
                            PortCardView(
                                port: port,
                                processIcon: viewModel.processIcons[port.process.pid],
                                onToggleFavorite: { viewModel.toggleFavorite(port) },
                                onKill: { Task { await viewModel.killProcess(port) } }
                            )
                        }
                    }
                    .padding(.horizontal, Constants.Spacing.medium)
                    .padding(.vertical, Constants.Spacing.small)
                }
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            HeaderView(
                lastScanTime: viewModel.lastScanTime,
                isScanning: viewModel.isScanning,
                onRefresh: {
                    Task { await viewModel.refresh() }
                },
                onSettings: {
                    SettingsWindowController.shared.open(viewModel: viewModel)
                }
            )

            SearchBarView(text: $viewModel.searchText)

            Spacer().frame(height: Constants.Spacing.medium)

            FilterTabsView(
                selectedTab: $viewModel.selectedTab,
                tabCount: { viewModel.tabCount(for: $0) }
            )

            Spacer().frame(height: Constants.Spacing.small)

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, Constants.Spacing.xlarge)

            if viewModel.selectedTab == .all {
                PortListView(
                    groupedPorts: viewModel.groupedPorts,
                    processIcons: viewModel.processIcons,
                    onToggleFavorite: { viewModel.toggleFavorite($0) },
                    onKill: { port in
                        Task { await viewModel.killProcess(port) }
                    },
                    onMoveToOther: { viewModel.moveToOther($0) },
                    onRestore: { viewModel.restoreCategory($0) }
                )
            } else if viewModel.selectedTab == .docker {
                dockerContainerList
            } else {
                portCardList
            }

            Divider()
                .background(Color.white.opacity(0.1))

            StatusBarView(
                portCount: viewModel.portCount,
                autoRefreshEnabled: SettingsManager.shared.autoRefreshEnabled,
                refreshInterval: SettingsManager.shared.refreshInterval
            )
        }
    }
}
