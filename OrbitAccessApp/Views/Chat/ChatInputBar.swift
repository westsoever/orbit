import SwiftUI

struct ChatInputBar: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    var showSpinOff: Bool = true
    var isCompact: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, isCompact ? 8 : 12)
            .frame(minHeight: isCompact ? 44 : 80, alignment: .top)

            Divider()
                .padding(.horizontal, 12)

            toolbarRow
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorder, lineWidth: 1)
        )
        .onChange(of: model.chatStore.focusRequested) { _, requested in
            if requested {
                isFocused = true
                model.chatStore.clearFocusRequest()
            }
        }
    }

    private var toolbarRow: some View {
        HStack(spacing: 8) {
            if !isCompact {
                attachButton
            }

            if !isCompact {
                ChatIntegrationsStrip()
                    .frame(maxWidth: .infinity)
            } else {
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if showSpinOff {
                    spinOffButton
                }
                sendButton
            }
        }
    }

    private var attachButton: some View {
        Button {} label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                .frame(width: 28, height: 28)
                .background(Color.orbitSecondaryText(for: colorScheme).opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(true)
        .help("Attachments coming soon")
    }

    private var placeholderText: String {
        model.isDaemonOnline
            ? "Ask Orbit anything…"
            : "Start the daemon from the sidebar to enable search & chat"
    }

    private var sendButton: some View {
        Button(action: sendMessage) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    canSend ? Color(white: 0.15) : Color.orbitSecondaryText(for: colorScheme),
                    in: Circle()
                )
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

    private var cardSurface: Color {
        colorScheme == .dark ? .orbitCardDark : .orbitCardLight
    }

    private var cardBorder: Color {
        colorScheme == .dark ? .orbitCardBorderDark : .orbitCardBorderLight
    }

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
