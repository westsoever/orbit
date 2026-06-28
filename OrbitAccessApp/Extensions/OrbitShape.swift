import SwiftUI

enum OrbitShape {
    static let radiusCard: CGFloat = 8
    static let radiusChip: CGFloat = 6
    static let radiusControl: CGFloat = 4
    static let borderHairlineWidth: CGFloat = 0.5
    static let surfaceMutedOpacity: Double = 0.04
    static let borderHairlineOpacity: Double = 0.08
    static let dividerHairlineOpacity: Double = 0.06
}

extension Color {
    static func orbitSurfaceMuted(for colorScheme: ColorScheme) -> Color {
        Color.primary.opacity(OrbitShape.surfaceMutedOpacity)
    }

    static func orbitBorderHairline(for colorScheme: ColorScheme) -> Color {
        Color.primary.opacity(OrbitShape.borderHairlineOpacity)
    }

    static func orbitDividerHairline(for colorScheme: ColorScheme) -> Color {
        Color.primary.opacity(OrbitShape.dividerHairlineOpacity)
    }
}

extension View {
    func orbitHairlineBorder(
        cornerRadius: CGFloat = OrbitShape.radiusCard,
        colorScheme: ColorScheme
    ) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    Color.orbitBorderHairline(for: colorScheme),
                    lineWidth: OrbitShape.borderHairlineWidth
                )
        )
    }
}
