import SwiftUI

struct RecentCaptureList: View {
    let events: [ContextEvent]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if events.isEmpty {
            Text("No recent captures")
                .font(.caption)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 6) {
                ForEach(events) { event in
                    captureRow(event)
                }
            }
        }
    }

    private func captureRow(_ event: ContextEvent) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "app")
                .font(.caption)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.appName ?? "Unknown App")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                if let title = event.windowTitle, !title.isEmpty {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(formatTimestamp(event.timestamp))
                .font(.caption2)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatTimestamp(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: timestamp) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return String(timestamp.suffix(8))
    }
}
