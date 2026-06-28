import SwiftUI

struct ChatIntegrationsStrip: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Text("Connect your apps to get better answers")
                .font(.caption)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: "number")
                Image(systemName: "doc.text")
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                Image(systemName: "calendar")
            }
            .font(.system(size: 16))
            .foregroundStyle(Color.orbitSecondaryText(for: colorScheme).opacity(0.7))
        }
        .allowsHitTesting(false)
    }
}
