import SwiftUI

struct AgentsDropdownMenu: View {
    @Environment(AppViewModel.self) private var model
    @State private var lastSelection: String?

    private let agents: [AgentType] = [.writing, .research, .code, .admin]

    private var triggerTitle: String {
        if let lastSelection {
            return "Agents · \(lastSelection)"
        }
        return "Agents"
    }

    var body: some View {
        SidePaneDropdownTrigger(title: triggerTitle, icon: "person.2") {
            ForEach(agents, id: \.self) { agent in
                Button {
                    lastSelection = agent.displayName
                    Task { await AgentPromptFunction(agentType: agent).execute(model.aiContext()) }
                } label: {
                    Label(agent.displayName, systemImage: agent.icon)
                }
            }
        }
    }
}
