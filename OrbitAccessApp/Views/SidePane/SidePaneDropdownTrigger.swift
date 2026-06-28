import SwiftUI

struct SidePaneDropdownTrigger<MenuContent: View>: View {
    let title: String
    let icon: String
    var iconColor: Color = Color.orbitAccent
    @ViewBuilder let menuContent: () -> MenuContent

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 20, height: 18, alignment: .leading)
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .kerning(-0.1)
                    .lineLimit(1)
                    .padding(.leading, 8)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14, alignment: .trailing)
                    .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.clear, in: RoundedRectangle(cornerRadius: OrbitShape.radiusControl))
            .orbitHairlineBorder(cornerRadius: OrbitShape.radiusControl, colorScheme: colorScheme)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }
}
