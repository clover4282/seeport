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

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, Constants.Spacing.xlarge)

            PortListView(
                groupedPorts: viewModel.groupedPorts,
                processIcons: viewModel.processIcons,
                onToggleFavorite: { viewModel.toggleFavorite($0) },
                onKill: { port in
                    Task { await viewModel.killProcess(port) }
                },
                onMoveToSystem: { viewModel.moveToSystem($0) },
                onRestore: { viewModel.restoreCategory($0) }
            )

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
