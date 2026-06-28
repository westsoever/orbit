import SwiftUI

struct SidebaneCaptureFooter: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.body)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.insightStore.atomsCapturedToday)")
                    .font(.body.weight(.medium))
                    .kerning(-0.1)
                Text("atoms captured today")
                    .font(.caption2)
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
            }
            Spacer(minLength: 4)
            Button {
                openPrivacyPolicy()
            } label: {
                Image(systemName: "hand.raised")
                    .font(.callout)
            }
            .buttonStyle(OrbitFlatButtonStyle(variant: .secondary))
            .help("Privacy Policy")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func openPrivacyPolicy() {
        guard let url = OrbitPaths.privacyPolicyURL() else { return }
        NSWorkspace.shared.open(url)
    }
}
