import SwiftUI

/// Renders one owner (Docker container or process) that listens on multiple ports.
/// The first port reuses the standard `PortRowView` so the layout is identical to
/// single rows; the remaining ports hang below as slim rows sharing the same port
/// column, with a left accent binding them into one group.
struct PortClusterView: View {
    let ports: [PortInfo]
    let processIcons: [Int32: NSImage]
    let onToggleFavorite: (PortInfo) -> Void
    let onKill: (PortInfo) -> Void
    let onMoveToSystem: (PortInfo) -> Void
    var onRestore: ((PortInfo) -> Void)?

    private var head: PortInfo { ports[0] }

    var body: some View {
        VStack(spacing: 0) {
            PortRowView(
                port: head,
                processIcon: processIcons[head.process.pid],
                onToggleFavorite: { onToggleFavorite(head) },
                onKill: { onKill(head) },
                onMoveToSystem: { onMoveToSystem(head) },
                onRestore: CategoryOverrides.categoryFor(head.port) != nil ? { onRestore?(head) } : nil
            )

            ForEach(ports.dropFirst()) { port in
                ExtraPortRow(port: port, onToggleFavorite: { onToggleFavorite(port) })
            }
        }
    }
}

/// A secondary port of a clustered owner: same column metrics as `PortRowView`
/// (80pt port column, 16/8 padding) but without the repeated icon and name.
private struct ExtraPortRow: View {
    let port: PortInfo
    let onToggleFavorite: () -> Void

    @State private var isHovering = false
    @State private var isPortHovering = false

    var body: some View {
        HStack(spacing: Constants.Spacing.large) {
            Button(action: onToggleFavorite) {
                Image(systemName: port.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundColor(port.isFavorite ? .yellow : Constants.Colors.textSecondary.opacity(0.4))
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .hoverCursor()

            Text(String(port.port))
                .font(Constants.Fonts.portNumber)
                .foregroundColor(isPortHovering ? port.category.color.opacity(0.6) : port.category.color)
                .underline(isPortHovering)
                .frame(width: 80, alignment: .leading)
                .minimumScaleFactor(0.8)
                .onTapGesture {
                    BrowserLauncher.open(address: port.address, port: port.port)
                }
                .onHover { hovering in
                    isPortHovering = hovering
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

            Spacer()
        }
        .padding(.horizontal, Constants.Spacing.xlarge)
        .frame(height: Constants.rowHeight)
        .background(isHovering ? Constants.Colors.cardBackground : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
    }
}
