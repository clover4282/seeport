import SwiftUI

struct CategoryHeaderView: View {
    let category: PortCategory
    let count: Int

    var body: some View {
        HStack(spacing: Constants.Spacing.medium) {
            Image(systemName: category.icon)
                .font(.system(size: 11))
                .foregroundColor(category.color)

            Text(category.rawValue)
                .font(Constants.Fonts.sectionHeader)
                .foregroundColor(Constants.Colors.textSecondary)

            Text("\(count)")
                .font(.system(size: 10))
                .foregroundColor(Constants.Colors.textSecondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.08))
                .cornerRadius(3)

            Spacer()
        }
        .padding(.horizontal, Constants.Spacing.xlarge)
        .padding(.top, Constants.Spacing.large)
        .padding(.bottom, Constants.Spacing.small)
    }
}
