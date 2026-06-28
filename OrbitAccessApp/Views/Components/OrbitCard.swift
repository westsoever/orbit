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
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    private var cardSurface: Color {
        colorScheme == .dark ? .orbitCardDark : .orbitCardLight
    }

    private var cardBorder: Color {
        colorScheme == .dark ? .orbitCardBorderDark : .orbitCardBorderLight
    }
}
