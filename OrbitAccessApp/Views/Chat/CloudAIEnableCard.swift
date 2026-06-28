import SwiftUI

struct CloudAIEnableCard: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEnabling = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enable Cloud AI")
                .font(.subheadline.weight(.semibold))

            Text(
                "Get AI answers from your captured context. Context snippets from your question " +
                "are sent to Orbit's AI service — nothing else leaves your Mac."
            )
            .font(.caption)
            .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))

            HStack(spacing: 12) {
                Button(action: enableCloudAI) {
                    if isEnabling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Enable Cloud AI")
                    }
                }
                .buttonStyle(OrbitFlatButtonStyle(variant: .primary))
                .disabled(isEnabling)

                Button("Settings…") {
                    model.showCloudAISettings = true
                }
                .buttonStyle(OrbitFlatButtonStyle(variant: .secondary))
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: OrbitShape.radiusCard))
        .orbitHairlineBorder(cornerRadius: OrbitShape.radiusCard, colorScheme: colorScheme)
    }

    private var cardSurface: Color {
        colorScheme == .dark ? .orbitCardDark : .orbitCardLight
    }

    private func enableCloudAI() {
        isEnabling = true
        errorMessage = nil
        Task {
            defer { isEnabling = false }
            do {
                _ = try await CloudAIService.shared.register()
                await MainActor.run { model.refreshCloudAIState() }
            } catch let urlError as URLError {
                let unreachable: Set<URLError.Code> = [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .timedOut, .notConnectedToInternet]
                let message = unreachable.contains(urlError.code)
                    ? "Cloud AI service is unreachable. Make sure the relay is running (or set ORBIT_RELAY_URL)."
                    : urlError.localizedDescription
                await MainActor.run { errorMessage = message }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
