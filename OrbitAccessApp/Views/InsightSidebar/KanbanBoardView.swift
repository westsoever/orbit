import SwiftUI

struct KanbanBoardView: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    @State private var isDetecting = false
    @State private var detectError: String?

    private let columns: [(title: String, status: String)] = [
        ("Detected", "detected"),
        ("Approved", "approved"),
        ("Done", "dispatched"),
        ("Skipped", "skipped"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Task board")
                    .font(.headline)
                Spacer()
                Button(action: detectTasks) {
                    if isDetecting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Scan capture", systemImage: "sparkles")
                    }
                }
                .buttonStyle(OrbitFlatButtonStyle(variant: .secondary))
                .disabled(isDetecting || !model.canUseLiveServices)
            }

            if let detectError {
                Text(detectError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !model.canUseLiveServices {
                Text("Start capture to scan your recent activity for tasks.")
                    .font(.caption)
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(columns, id: \.status) { column in
                        kanbanColumn(title: column.title, status: column.status)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func kanbanColumn(title: String, status: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))

            let tasks = model.taskStore.kanbanTasks.filter { $0.status == status }
            if tasks.isEmpty {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                    .frame(width: 200, minHeight: 60, alignment: .topLeading)
            } else {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        TaskCard(task: task)
                            .frame(width: 200)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.clear, in: RoundedRectangle(cornerRadius: OrbitShape.radiusCard))
        .orbitHairlineBorder(cornerRadius: OrbitShape.radiusCard, colorScheme: colorScheme)
    }

    private func detectTasks() {
        isDetecting = true
        detectError = nil
        Task {
            defer { isDetecting = false }
            do {
                try await model.taskStore.detectFromCapture(bridge: model.bridge)
            } catch {
                detectError = error.localizedDescription
            }
        }
    }
}
