import SwiftUI

struct StatusBarPopoverView: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Orbit")
                    .font(.headline)
                    .kerning(-0.1)
                Spacer()
                statusDot
            }

            ProductivityScoreGauge(score: model.insightStore.productivityScore.value)
                .scaleEffect(0.85)

            HStack {
                Label("\(model.taskStore.pendingTasks.count) tasks", systemImage: "checklist")
                    .font(.caption)
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                Spacer()
                if let lastApp = model.insightStore.recentCaptures.first?.appName {
                    Label(lastApp, systemImage: "app")
                        .font(.caption)
                        .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                        .lineLimit(1)
                }
            }

            Button("Open Orbit") {
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.orbitAccent)
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                if model.isDaemonOnline {
                    Button("Stop daemon") {
                        Task { await model.stopDaemon() }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Start daemon") {
                        Task { await model.startDaemon() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.orbitAccent)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: 280)
    }

    private var statusDot: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 6, height: 6)
            Text(statusLabel)
                .font(.caption2)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
        }
    }

    private var statusDotColor: Color {
        if !model.canBrowseContext { return .red }
        if model.canUseLiveServices { return .green }
        return .orange
    }

    private var statusLabel: String {
        if !model.canBrowseContext { return "No database" }
        if model.canUseLiveServices { return "Online" }
        return "Browse only"
    }
}

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}
