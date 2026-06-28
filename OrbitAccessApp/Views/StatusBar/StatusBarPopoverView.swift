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
        }
        .padding(16)
        .frame(width: 280)
    }

    private var statusDot: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(model.isDaemonOnline ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            Text(model.isDaemonOnline ? "Online" : "Offline")
                .font(.caption2)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
        }
    }
}

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}
