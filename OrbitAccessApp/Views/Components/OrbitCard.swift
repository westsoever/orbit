import SwiftUI

struct OrbitCard<Content: View>: View {
    var accent: Color = .clear
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            if accent != .clear {
                accent
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
            }
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(cardSurface, in: RoundedRectangle(cornerRadius: OrbitShape.radiusCard))
        .orbitHairlineBorder(cornerRadius: OrbitShape.radiusCard, colorScheme: colorScheme)
    }

    private var cardSurface: Color {
        colorScheme == .dark ? .orbitCardDark : .orbitCardLight
    }

}
