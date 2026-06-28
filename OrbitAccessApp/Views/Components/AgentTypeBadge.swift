import SwiftUI

struct AgentTypeBadge: View {
    let agentType: AgentType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: agentType.icon)
                .font(.caption2)
            Text(agentType.displayName)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(agentType.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(agentType.color.opacity(0.12), in: RoundedRectangle(cornerRadius: OrbitShape.radiusControl))
    }
}
