import SwiftUI

struct ChatHeroView: View {
    var greeting: String = "Got something for me?"
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme).opacity(0.6))
            Text(greeting)
                .font(.system(size: 26, weight: .medium))
                .kerning(-0.3)
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
        }
        .multilineTextAlignment(.center)
    }
}
