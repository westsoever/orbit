import SwiftUI

struct SidebaneView: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SidePaneSectionHeader(title: "Search")
                if model.searchStore.panelActive {
                    SidebaneSearchPanel()
                }
                SearchDropdownMenu()

                SidePaneSectionHeader(title: "Agents")
                AgentsDropdownMenu()

                SidePaneSectionHeader(title: "Capture")
                DaemonStatusIndicator()
                CaptureStatsView()

                SidePaneSectionHeader(title: "Privacy")
                PrivacyPolicyLink()
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .frame(maxHeight: .infinity)
    }
}

private struct PrivacyPolicyLink: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            openPrivacyPolicy()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised")
                    .font(.body)
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                    .frame(width: 20)
                Text("Privacy Policy")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .kerning(-0.1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openPrivacyPolicy() {
        guard let url = OrbitPaths.privacyPolicyURL() else { return }
        NSWorkspace.shared.open(url)
    }
}
