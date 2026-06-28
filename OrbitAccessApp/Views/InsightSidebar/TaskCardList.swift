import SwiftUI

struct TaskCardList: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if model.taskStore.isLoading && model.taskStore.pendingTasks.isEmpty {
                LoadingIndicator(label: "Loading tasks…")
            } else if model.taskStore.pendingTasks.isEmpty {
                Text("No pending tasks")
                    .font(.caption)
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(model.taskStore.pendingTasks) { task in
                        TaskCard(task: task)
                    }
                }
            }
        }
    }
}
