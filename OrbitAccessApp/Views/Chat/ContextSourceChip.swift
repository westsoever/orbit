import SwiftUI

struct ContextSourceChip: View {
    let atom: SearchHit
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.caption2)
                Text(chipLabel)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(Color.orbitAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orbitAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: OrbitShape.radiusChip))
        }
        .buttonStyle(.plain)
    }

    private var chipLabel: String {
        let app = atom.appName.isEmpty ? "Unknown" : atom.appName
        if let title = atom.windowTitle, !title.isEmpty {
            return "\(app) · \(title)"
        }
        return app
    }
}
