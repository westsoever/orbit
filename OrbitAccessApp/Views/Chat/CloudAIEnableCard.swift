import SwiftUI

struct CloudAIEnableCard: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedMode: AIMode = .cloud
    @State private var localModelName = LLMPreferencesService.defaultLocalModel
    @State private var apiKey = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose how Orbit answers")
                .font(.subheadline.weight(.semibold))

            Picker("AI mode", selection: $selectedMode) {
                ForEach(AIMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedMode.subtitle)
                .font(.caption)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))

            if selectedMode == .local {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ollama model name")
                        .font(.caption.weight(.medium))
                    TextField("llama3.1", text: $localModelName)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .padding(10)
                        .background(Color.clear, in: RoundedRectangle(cornerRadius: OrbitShape.radiusControl))
                        .orbitHairlineBorder(cornerRadius: OrbitShape.radiusControl, colorScheme: colorScheme)
                    Text("Run `ollama serve`, then `ollama pull \(localModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "llama3.1" : localModelName)`.")
                        .font(.caption2)
                        .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                }
            }

            if selectedMode == .byok {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OpenRouter API key")
                        .font(.caption.weight(.medium))
                    SecureField("sk-or-v1-…", text: $apiKey)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .padding(10)
                        .background(Color.clear, in: RoundedRectangle(cornerRadius: OrbitShape.radiusControl))
                        .orbitHairlineBorder(cornerRadius: OrbitShape.radiusControl, colorScheme: colorScheme)
                }
            }

            HStack(spacing: 12) {
                Button(action: saveSelection) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(saveButtonTitle)
                    }
                }
                .buttonStyle(OrbitFlatButtonStyle(variant: .primary))
                .disabled(isSaving || !canSave)

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
        .onAppear {
            if let mode = model.aiMode {
                selectedMode = mode
            }
            if let modelName = model.localModelName {
                localModelName = modelName
            }
        }
    }

    private var cardSurface: Color {
        colorScheme == .dark ? .orbitCardDark : .orbitCardLight
    }

    private var saveButtonTitle: String {
        switch selectedMode {
        case .cloud: return "Enable Cloud AI"
        case .local: return "Use local model"
        case .byok: return "Save API key"
        }
    }

    private var canSave: Bool {
        switch selectedMode {
        case .cloud: return true
        case .local: return !localModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .byok: return apiKey.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
        }
    }

    private func saveSelection() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                switch selectedMode {
                case .cloud:
                    try await LLMPreferencesService.shared.configureCloud()
                case .local:
                    try LLMPreferencesService.shared.configureLocal(model: localModelName)
                case .byok:
                    try LLMPreferencesService.shared.configureBYOK(apiKey: apiKey)
                    apiKey = ""
                }
                await MainActor.run { model.refreshAIState() }
            } catch {
                await MainActor.run {
                    errorMessage = ChatErrorFormatter.aiSetupMessage(for: error)
                }
            }
        }
    }
}
