import SwiftUI

struct CloudAISettingsView: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEnabling = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Orbit Cloud AI", isOn: Binding(
                get: { model.isCloudAIEnabled },
                set: { enabled in
                    Task { await setEnabled(enabled) }
                }
            ))
            .disabled(isEnabling)

            Text(
                "Context snippets from your question are sent to Orbit's AI service to generate answers. " +
                "Nothing else leaves your Mac."
            )
            .font(.caption)
            .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))

            Text("About 40 messages per day on the shared plan.")
                .font(.caption2)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))

            Button("Use your own API key instead") {
                CloudAIService.shared.openOrbitDirectory()
            }
            .font(.caption)
            .buttonStyle(.link)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: 360, alignment: .leading)
    }

    @MainActor
    private func setEnabled(_ enabled: Bool) async {
        errorMessage = nil
        if enabled {
            isEnabling = true
            defer { isEnabling = false }
            do {
                _ = try await CloudAIService.shared.register()
                model.refreshCloudAIState()
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            do {
                try CloudAIService.shared.disable()
                model.refreshCloudAIState()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
