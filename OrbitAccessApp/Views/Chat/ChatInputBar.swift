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
            .disabled(!canType)
            .onSubmit { sendMessage() }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(minHeight: isCompact ? 44 : 72, alignment: .top)

            OrbitHairlineDivider()

            toolbarRow
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            if !isCompact {
                OrbitHairlineDivider()
                ChatSuggestionChips()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .background(cardSurface, in: RoundedRectangle(cornerRadius: OrbitShape.radiusCard))
        .orbitHairlineBorder(cornerRadius: OrbitShape.radiusCard, colorScheme: colorScheme)
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
            }

            Spacer(minLength: 0)

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
            Image(systemName: "paperclip")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(true)
        .help("Attachments coming soon")
    }

    private var canType: Bool {
        model.canBrowseContext || model.canUseLiveServices
    }

    private var placeholderText: String {
        if model.isDaemonStarting {
            return "Orbit is starting…"
        }
        if !model.canBrowseContext {
            return "Waiting for Orbit database…"
        }
        if model.canUseAIChat {
            if model.aiMode == .local, let name = model.localModelName {
                return "Ask Orbit anything… (local: \(name))"
            }
            if model.aiMode == .cloud {
                return "Ask Orbit anything… (Cloud AI)"
            }
            return "Ask Orbit anything…"
        }
        if model.canSearchLocally {
            return "Search your saved context (configure AI above for full answers)…"
        }
        return "Orbit is starting…"
    }

    private var sendButton: some View {
        Button(action: sendMessage) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    canSend ? Color(white: 0.15) : Color.orbitSecondaryText(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: OrbitShape.radiusChip)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .keyboardShortcut(.return, modifiers: .command)
        .help(sendHelp)
    }

    private var sendHelp: String {
        if model.canUseAIChat {
            switch model.aiMode {
            case .cloud: return "Send message via Cloud AI"
            case .local: return "Send message via local Ollama model"
            case nil: return "Send message (AI or keyword fallback)"
            }
        }
        return "Search saved context"
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

    private var canSend: Bool {
        !model.chatStore.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.chatStore.isStreaming
            && (model.canUseLiveServices || model.canSearchLocally)
    }

    private func sendMessage() {
        guard canSend else { return }
        Task {
            await model.chatStore.send(
                canUseLiveServices: model.canUseLiveServices,
                canSearchLocally: model.canSearchLocally,
                hasDatabase: model.canBrowseContext
            )
        }
    }

    private func spinOffChat() {
        chatIsFloating = true
        openWindow(id: "floating-chat")
    }
}
