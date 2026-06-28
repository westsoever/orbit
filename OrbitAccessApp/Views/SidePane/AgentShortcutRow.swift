import SwiftUI

struct AgentShortcutRow: View {
    @Environment(AppViewModel.self) private var model
    let agentType: AgentType

    var body: some View {
        Button {
            Task { await AgentPromptFunction(agentType: agentType).execute(model.aiContext()) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: agentType.icon)
                    .font(.body)
                    .foregroundStyle(agentType.color)
                    .frame(width: 20)
                Text(agentType.displayName)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .kerning(-0.1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(agentType.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
