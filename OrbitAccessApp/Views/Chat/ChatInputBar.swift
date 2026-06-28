import SwiftUI

struct ChatInputBar: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    var showSpinOff: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(
                placeholderText,
                text: Bindable(model.chatStore).inputText,
                axis: .vertical
            )
            .lineLimit(1...6)
            .textFieldStyle(.plain)
            .font(.body)
            .kerning(-0.1)
            .focused($isFocused)
            .disabled(!model.isDaemonOnline)
            .onSubmit { sendMessage() }

            if showSpinOff {
                spinOffButton
            }

            sendButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: model.chatStore.focusRequested) { _, requested in
            if requested {
                isFocused = true
                model.chatStore.clearFocusRequest()
            }
        }
    }

    private var placeholderText: String {
        model.isDaemonOnline
            ? "Ask Orbit anything…"
            : "Start `orbit start` to enable search & chat"
    }

    private var sendButton: some View {
        Button(action: sendMessage) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(canSend ? Color.orbitAccent : Color.orbitSecondaryText(for: colorScheme))
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .keyboardShortcut(.return, modifiers: .command)
        .help("Send message")
    }

    private var spinOffButton: some View {
        Button(action: spinOffChat) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.body)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
        }
        .buttonStyle(.plain)
        .help("Pop out chat")
    }

    @Environment(\.openWindow) private var openWindow
    @AppStorage("chatIsFloating") private var chatIsFloating = false

    private var canSend: Bool {
        model.isDaemonOnline && !model.chatStore.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.chatStore.isStreaming
    }

    private func sendMessage() {
        guard canSend else { return }
        Task { await model.chatStore.send() }
    }

    private func spinOffChat() {
        chatIsFloating = true
        openWindow(id: "floating-chat")
    }
}
