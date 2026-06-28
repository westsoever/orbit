import SwiftUI

struct OrbitFlatButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
    }

    var variant: Variant = .secondary
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: variant == .primary ? .infinity : nil)
            .background(background(configuration: configuration), in: RoundedRectangle(cornerRadius: OrbitShape.radiusControl))
            .overlay(
                RoundedRectangle(cornerRadius: OrbitShape.radiusControl)
                    .stroke(borderColor, lineWidth: variant == .secondary ? OrbitShape.borderHairlineWidth : 0)
            )
            .foregroundStyle(foregroundColor)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: return .white
        case .secondary: return .primary
        }
    }

    private var borderColor: Color {
        Color.orbitBorderHairline(for: colorScheme)
    }

    private func background(configuration: Configuration) -> Color {
        switch variant {
        case .primary:
            return Color(white: configuration.isPressed ? 0.25 : 0.15)
        case .secondary:
            return configuration.isPressed
                ? Color.orbitSurfaceMuted(for: colorScheme)
                : .clear
        }
    }
}
