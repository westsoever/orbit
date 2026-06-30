import SwiftUI

struct MainChatView: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    private var isLandingMode: Bool {
        model.chatStore.messages.isEmpty && !model.chatStore.isStreaming
    }

    var body: some View {
        Group {
            if isLandingMode {
                landingView
            } else {
                conversationView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLandingMode)
        .background(Color.orbitChatBackground(for: colorScheme))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: Bindable(model).showCloudAISettings) {
            CloudAISettingsView()
                .padding()
        }
    }

    private var landingView: some View {
        VStack {
            Spacer(minLength: 32)
            ChatHeroView()
            Spacer(minLength: 20)
            VStack(spacing: 12) {
                if model.shouldShowCloudAIEnablePrompt {
                    CloudAIEnableCard()
                }
                ChatInputBar(showSpinOff: true, isCompact: false)
                chatStatusBadge
                chatErrorBanner
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }

    private var conversationView: some View {
        VStack(spacing: 8) {
            ChatMessageList(messages: model.chatStore.messages, isStreaming: model.chatStore.isStreaming)

            if let errorMessage = model.chatStore.errorMessage {
                chatErrorBannerContent(errorMessage)
                    .padding(.horizontal, 22)
            }

            ChatInputBar(showSpinOff: true, isCompact: true)
                .padding(.horizontal, 16)

            if model.shouldShowCloudAIEnablePrompt {
                CloudAIEnableCard()
                    .padding(.horizontal, 16)
            }

            chatStatusBadge
                .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    private var chatStatusBadge: some View {
        Group {
            if let text = chatStatusText {
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var chatErrorBanner: some View {
        if let errorMessage = model.chatStore.errorMessage {
            chatErrorBannerContent(errorMessage)
        }
    }

    private func chatErrorBannerContent(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chatStatusText: String? {
        if model.canUseAIChat {
            if model.hasConfiguredAI {
                if model.isCloudAIEnabled {
                    return "Cloud AI is enabled."
                }
                if model.cloudAI.hasBYOK() {
                    return "Using your API key from ~/.orbit/.env."
                }
                if model.cloudAI.hasLocalLLMConfigured() {
                    return "Using a local model (Ollama)."
                }
            }
            return nil
        }
        if model.canSearchLocally {
            return "Offline mode — keyword search over saved context. Start the daemon for AI answers."
        }
        return nil
    }
}
