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
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .kerning(-0.1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.clear, in: RoundedRectangle(cornerRadius: OrbitShape.radiusControl))
            .orbitHairlineBorder(cornerRadius: OrbitShape.radiusControl, colorScheme: colorScheme)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }
}
