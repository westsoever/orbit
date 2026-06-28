import SwiftUI

struct SidePaneSectionHeader: View {
    let title: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
