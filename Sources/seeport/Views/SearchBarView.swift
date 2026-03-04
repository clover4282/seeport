import SwiftUI

struct SearchBarView: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: Constants.Spacing.medium) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(Constants.Colors.textSecondary)

            TextField("Search ports, processes, containers...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(Constants.Colors.textPrimary)
                .onHover { hovering in
                    if hovering {
                        NSCursor.iBeam.push()
                    } else {
                        NSCursor.pop()
                    }
                }

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .hoverCursor()
            }
        }
        .padding(Constants.Spacing.medium)
        .background(Constants.Colors.searchBackground)
        .cornerRadius(8)
        .padding(.horizontal, Constants.Spacing.xlarge)
    }
}
