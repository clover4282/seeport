import SwiftUI

struct StatusBarView: View {
    let portCount: Int
    let autoRefreshEnabled: Bool
    let refreshInterval: TimeInterval

    var body: some View {
        HStack {
            HStack(spacing: Constants.Spacing.small) {
                Circle()
                    .fill(Constants.Colors.statusGreen)
                    .frame(width: 7, height: 7)

                Text("Ready")
                    .font(Constants.Fonts.detail)
                    .foregroundColor(Constants.Colors.textSecondary)

                Text("\u{2022}")
                    .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))

                Text("\(portCount) ports")
                    .font(Constants.Fonts.detail)
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            Spacer()

            if autoRefreshEnabled {
                Text("Auto-refresh: \(Int(refreshInterval))s")
                    .font(Constants.Fonts.detail)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
        }
        .padding(.horizontal, Constants.Spacing.xlarge)
        .padding(.vertical, Constants.Spacing.medium)
        .background(Constants.Colors.background.opacity(0.8))
    }
}
