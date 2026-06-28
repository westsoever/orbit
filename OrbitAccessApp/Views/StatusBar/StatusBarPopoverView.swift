import SwiftUI

struct StatusBarPopoverView: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Orbit")
                    .font(.headline)
                    .kerning(-0.1)
                Spacer()
                statusDot
            }
            .padding(.bottom, 12)

            OrbitHairlineDivider(horizontalPadding: 0)

            ProductivityScoreGauge(score: model.insightStore.productivityScore.value)
                .scaleEffect(0.85)
                .padding(.vertical, 12)

            OrbitHairlineDivider(horizontalPadding: 0)

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
            .padding(.vertical, 12)

            OrbitHairlineDivider(horizontalPadding: 0)

            VStack(spacing: 8) {
                Button("Open Orbit") {
                    NotificationCenter.default.post(name: .openMainWindow, object: nil)
                }
                .buttonStyle(OrbitFlatButtonStyle(variant: .primary))

                HStack(spacing: 8) {
                    if isTransitioning {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else if model.isDaemonOnline {
                        Button("Stop daemon") {
                            Task { await model.stopDaemon() }
                        }
                        .buttonStyle(OrbitFlatButtonStyle(variant: .secondary))
                        .frame(maxWidth: .infinity)
                    } else {
                        Button("Start daemon") {
                            Task { await model.startDaemon() }
                        }
                        .buttonStyle(OrbitFlatButtonStyle(variant: .primary))
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 12)

            if case .error(let message) = model.daemonControlState {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Color.red)
                    .lineLimit(2)
                    .padding(.top, 8)
            }
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

    private var isTransitioning: Bool {
        switch model.daemonControlState {
        case .starting, .stopping:
            return true
        default:
            return false
        }
    }
}

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}
