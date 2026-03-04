import SwiftUI

struct FilterTabsView: View {
    @Binding var selectedTab: FilterTab
    let tabCount: (FilterTab) -> Int

    var body: some View {
        HStack(spacing: Constants.Spacing.small) {
            ForEach(FilterTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, Constants.Spacing.xlarge)
    }

    private func tabButton(_ tab: FilterTab) -> some View {
        Button(action: { selectedTab = tab }) {
            HStack(spacing: 4) {
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))

                Text("\(tabCount(tab))")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        selectedTab == tab
                            ? Constants.Colors.accent.opacity(0.3)
                            : Color.white.opacity(0.1)
                    )
                    .cornerRadius(4)
            }
            .foregroundColor(
                selectedTab == tab
                    ? Constants.Colors.accent
                    : Constants.Colors.textSecondary
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                selectedTab == tab
                    ? Constants.Colors.accent.opacity(0.15)
                    : Color.clear
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .hoverCursor()
    }
}
