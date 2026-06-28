import SwiftUI

struct DaemonStatusIndicator: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var capturePulse = false

    var body: some View {
        HStack(spacing: 8) {
            statusDot
            VStack(alignment: .leading, spacing: 2) {
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(labelColor)
                    .kerning(-0.1)
                if !model.isDaemonOnline && !isTransitioning {
                    Text("Capture & chat need the daemon")
                        .font(.caption2)
                        .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                }
                if case .error(let message) = model.daemonControlState {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(Color.red)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            controlView
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onChange(of: model.isCaptureActive) { _, active in
            if active && model.isDaemonOnline {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    capturePulse = true
                }
            } else {
                capturePulse = false
            }
        }
        .onAppear {
            if model.isCaptureActive && model.isDaemonOnline {
                capturePulse = true
            }
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        if isTransitioning {
            ProgressView()
                .controlSize(.small)
                .frame(width: 8, height: 8)
        } else {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .scaleEffect(model.isCaptureActive && model.isDaemonOnline && capturePulse ? 1.35 : 1.0)
                .animation(
                    model.isCaptureActive && model.isDaemonOnline
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: capturePulse
                )
        }
    }

    @ViewBuilder
    private var controlView: some View {
        if isTransitioning {
            ProgressView()
                .controlSize(.small)
        } else if model.isDaemonOnline {
            Button("Stop") {
                Task { await model.stopDaemon() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else {
            Button("Start") {
                Task { await model.startDaemon() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.orbitAccent)
            .controlSize(.small)
        }
    }

    private var isTransitioning: Bool {
        switch model.daemonControlState {
        case .starting, .stopping:
            return true
        default:
            return false
        }
    }

    private var statusLabel: String {
        switch model.daemonControlState {
        case .starting:
            return "Starting…"
        case .stopping:
            return "Stopping…"
        case .error:
            return "Daemon offline"
        case .running, .offline:
            if model.isDaemonOnline {
                return model.isCaptureActive ? "Capturing" : "Daemon running"
            }
            return "Daemon offline"
        }
    }

    private var dotColor: Color {
        if model.isDaemonOnline {
            return model.isCaptureActive ? Color.green : Color.green
        }
        return Color.red
    }

    private var labelColor: Color {
        model.isDaemonOnline ? Color.primary : Color.red
    }
}
