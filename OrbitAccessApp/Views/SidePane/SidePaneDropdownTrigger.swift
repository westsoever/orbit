import SwiftUI

private enum SidePaneRowMetrics {
    static let horizontalPadding: CGFloat = 10
    static let rowHeight: CGFloat = 18
    static let verticalPadding: CGFloat = 9
    static let iconWidth: CGFloat = 20
    static let iconTextGap: CGFloat = 8
    static let chevronWidth: CGFloat = 14

    static var iconLeading: CGFloat { horizontalPadding }
    static var textLeading: CGFloat { horizontalPadding + iconWidth + iconTextGap }
}

struct SidePaneMenuRowLabel: View {
    let title: String
    let icon: String
    var iconColor: Color = Color.orbitAccent

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: SidePaneRowMetrics.chevronWidth, alignment: .trailing)
                    .padding(.trailing, SidePaneRowMetrics.horizontalPadding)
            }

            Text(title)
                .font(.callout)
                .foregroundStyle(.primary)
                .kerning(-0.1)
                .lineLimit(1)
                .padding(.leading, SidePaneRowMetrics.textLeading)

            Image(systemName: icon)
                .font(.callout.weight(.medium))
                .foregroundStyle(iconColor)
                .frame(width: SidePaneRowMetrics.iconWidth, alignment: .leading)
                .padding(.leading, SidePaneRowMetrics.iconLeading)
        }
        .frame(maxWidth: .infinity, minHeight: SidePaneRowMetrics.rowHeight, alignment: .leading)
        .padding(.vertical, SidePaneRowMetrics.verticalPadding)
        .background(Color.clear, in: RoundedRectangle(cornerRadius: OrbitShape.radiusControl))
        .orbitHairlineBorder(cornerRadius: OrbitShape.radiusControl, colorScheme: colorScheme)
        .contentShape(Rectangle())
    }
}

struct SidePaneDropdownTrigger<MenuContent: View>: View {
    let title: String
    let icon: String
    var iconColor: Color = Color.orbitAccent
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            SidePaneMenuRowLabel(title: title, icon: icon, iconColor: iconColor)
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
