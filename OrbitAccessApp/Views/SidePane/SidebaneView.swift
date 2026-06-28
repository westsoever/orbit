import SwiftUI

struct SidebaneView: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SidePaneSectionHeader(title: "SEARCH")
                if model.searchStore.panelActive {
                    SidebaneSearchPanel()
                }
                SidePaneSearchTrigger(title: "Semantic Search", icon: "magnifyingglass") {
                    Task { await SemanticSearchFunction().execute(model.aiContext()) }
                }
                SidePaneSearchTrigger(title: "Find by App", icon: "app.badge") {
                    Task { await FindByAppFunction().execute(model.aiContext()) }
                }
                SidePaneSearchTrigger(title: "Find by Time", icon: "clock") {
                    model.searchStore.activateFindByTime()
                }

                SidePaneSectionHeader(title: "AGENTS")
                AgentShortcutRow(agentType: .writing)
                AgentShortcutRow(agentType: .research)
                AgentShortcutRow(agentType: .code)
                AgentShortcutRow(agentType: .admin)

                SidePaneSectionHeader(title: "CAPTURE")
                DaemonStatusIndicator()
                CaptureStatsView()

                SidePaneSectionHeader(title: "PRIVACY")
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
