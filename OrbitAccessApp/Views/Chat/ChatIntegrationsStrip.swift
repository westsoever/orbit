import SwiftUI

struct ChatIntegrationsStrip: View {
    @Environment(\.colorScheme) private var colorScheme

    private let icons = ["magnifyingglass", "doc.text", "globe", "chevron.left.forwardslash.chevron.right"]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(icons, id: \.self) { icon in
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme).opacity(0.75))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Color.orbitSurfaceMuted(for: colorScheme),
            in: RoundedRectangle(cornerRadius: OrbitShape.radiusControl)
        )
        .allowsHitTesting(false)
        .help("Connect your apps to get better answers")
    }
}
