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
    }

    private var landingView: some View {
        VStack {
            Spacer(minLength: 40)
            ChatHeroView()
            Spacer(minLength: 24)
            VStack(spacing: 12) {
                ChatInputBar(showSpinOff: true, isCompact: false)
                ChatSuggestionChips()
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
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
            }

            ChatInputBar(showSpinOff: true, isCompact: true)
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }
}
