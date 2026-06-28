import SwiftUI

struct ChatHeroView: View {
    var greeting: String = "Got something for me?"
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            Text(greeting)
                .font(.system(size: 28, weight: .semibold))
                .kerning(-0.3)
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
        }
        .multilineTextAlignment(.center)
    }
}
