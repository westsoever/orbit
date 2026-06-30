import SwiftUI

struct CloudAISettingsView: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedMode: AIMode = .cloud
    @State private var localModelName = LLMPreferencesService.defaultLocalModel
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI answers")
                .font(.headline)

            Picker("Mode", selection: $selectedMode) {
                ForEach(AIMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedMode.subtitle)
                .font(.caption)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))

            if selectedMode == .cloud {
                cloudSection
            } else {
                localSection
            }

            HStack(spacing: 12) {
                Button(action: saveSelection) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(OrbitFlatButtonStyle(variant: .primary))
                .disabled(isSaving || (selectedMode == .local && localModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

                if model.hasConfiguredAI {
                    Button("Turn off AI") {
                        Task { await disableAI() }
                    }
                    .buttonStyle(OrbitFlatButtonStyle(variant: .secondary))
                    .disabled(isSaving)
                }
            }

            Button("Open ~/.orbit folder") {
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
        .frame(maxWidth: 420, alignment: .leading)
        .onAppear {
            if let mode = model.aiMode {
                selectedMode = mode
            }
            if let modelName = model.localModelName {
                localModelName = modelName
            }
        }
    }

    private var cloudSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Context snippets from your question are sent to Orbit's AI service. Nothing else leaves your Mac.")
                .font(.caption)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
            if model.isCloudAIEnabled {
                Text("Cloud AI is active on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var localSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model name")
                .font(.caption.weight(.medium))
            TextField("llama3.1", text: $localModelName)
                .textFieldStyle(.plain)
                .font(.callout)
                .padding(10)
                .background(Color.clear, in: RoundedRectangle(cornerRadius: OrbitShape.radiusControl))
                .orbitHairlineBorder(cornerRadius: OrbitShape.radiusControl, colorScheme: colorScheme)
            Text("Chat uses Ollama at \(LLMPreferencesService.defaultOllamaBaseURL). Start it with `ollama serve`.")
                .font(.caption2)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
        }
    }

    @MainActor
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
                }
                model.refreshAIState()
            } catch {
                errorMessage = ChatErrorFormatter.aiSetupMessage(for: error)
            }
        }
    }

    @MainActor
    private func disableAI() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try LLMPreferencesService.shared.disableAll()
            model.refreshAIState()
        } catch {
            errorMessage = ChatErrorFormatter.userMessage(for: error)
        }
    }
}
