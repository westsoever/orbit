import SwiftUI

struct MainChatView: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            ChatMessageList(messages: model.chatStore.messages, isStreaming: model.chatStore.isStreaming)
            Divider()
            if let errorMessage = model.chatStore.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            ChatInputBar(showSpinOff: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
