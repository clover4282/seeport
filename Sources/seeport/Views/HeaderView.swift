import SwiftUI

struct HeaderView: View {
    let lastScanTime: Date?
    let isScanning: Bool
    let onRefresh: () -> Void
    let onSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("see")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("port")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                }

                if let time = lastScanTime {
                    Text("Last scan: \(time, style: .time)")
                        .font(Constants.Fonts.detail)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: Constants.Spacing.medium) {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(Constants.Colors.textSecondary)
                        .rotationEffect(.degrees(isScanning ? 360 : 0))
                        .animation(
                            isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: isScanning
                        )
                }
                .buttonStyle(.plain)
                .hoverCursor()

                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .hoverCursor()

                Button(action: onQuit) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .hoverCursor()
            }
        }
        .padding(.horizontal, Constants.Spacing.xlarge)
        .padding(.vertical, Constants.Spacing.large)
    }
}
