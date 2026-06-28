import SwiftUI

struct ChatMessageList: View {
    let messages: [ChatMessage]
    let isStreaming: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        emptyState
                    }
                    ForEach(messages) { message in
                        ChatBubbleView(message: message)
                            .id(message.id)
                            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    }
                    if isStreaming {
                        LoadingIndicator(label: "Orbit is thinking…")
                            .id("streaming")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isStreaming) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
            Text("Ask Orbit anything about your context")
                .font(.callout)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if isStreaming {
            withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
        } else if let last = messages.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }
}
