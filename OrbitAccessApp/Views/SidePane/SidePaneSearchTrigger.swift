import SwiftUI

struct SidePaneSearchTrigger: View {
    let title: String
    let icon: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color.orbitAccent)
                    .frame(width: 20)
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .kerning(-0.1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.clear, in: RoundedRectangle(cornerRadius: OrbitShape.radiusControl))
            .orbitHairlineBorder(cornerRadius: OrbitShape.radiusControl, colorScheme: colorScheme)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
