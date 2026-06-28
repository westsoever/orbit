import SwiftUI

struct TaskCard: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let task: TaskLogEntry

    @State private var isExpanded = false
    @State private var isDismissed = false

    private var agentType: AgentType {
        AgentType(rawValueOrNil: task.agentType) ?? .writing
    }

    var body: some View {
        if !isDismissed {
            OrbitCard(accent: agentType.color) {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    bodyText
                    actions
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text(task.title ?? "Untitled Task")
                .font(.body.weight(.medium))
                .kerning(-0.1)
                .lineLimit(isExpanded ? nil : 2)
            Spacer()
            AgentTypeBadge(agentType: agentType)
        }
    }

    @ViewBuilder
    private var bodyText: some View {
        if let description = task.description, !description.isEmpty {
            Text(description)
                .font(.callout)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                .kerning(-0.1)
                .lineLimit(isExpanded ? nil : 3)
                .onTapGesture { withAnimation { isExpanded.toggle() } }
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button("Approve") {
                approveTask()
            }
            .buttonStyle(OrbitFlatButtonStyle(variant: .primary))
            .disabled(!model.canUseLiveServices)
            .help(model.canUseLiveServices ? "Approve task" : "Start daemon to approve")

            Button("Skip") {
                skipTask()
            }
            .buttonStyle(OrbitFlatButtonStyle(variant: .secondary))
            .disabled(!model.canUseLiveServices)
            .help(model.canUseLiveServices ? "Skip task" : "Start daemon to skip")

            Spacer()
        }
    }

    private func approveTask() {
        Task {
            let prompt = task.originalPrompt ?? task.title ?? ""
            try? await model.taskStore.approve(task: task, prompt: prompt)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isDismissed = true
            }
        }
    }

    private func skipTask() {
        Task {
            try? await model.taskStore.skip(task: task)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isDismissed = true
            }
        }
    }
}
