import SwiftUI

struct FloatingChatView: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            ChatMessageList(messages: model.chatStore.messages, isStreaming: model.chatStore.isStreaming)
            Divider()
            ChatInputBar(showSpinOff: false)
        }
        .frame(width: 360, height: 480)
    }
}
