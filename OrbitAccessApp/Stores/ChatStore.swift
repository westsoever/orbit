import Foundation
import Observation
import Combine

@Observable
final class ChatStore {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isStreaming = false
    var errorMessage: String?
    var focusRequested = false

    @ObservationIgnored private var bridge: OrbitBridgeProtocol?

    func configure(bridge: OrbitBridgeProtocol) {
        self.bridge = bridge
    }

    func prefillInput(_ text: String) {
        inputText = text
    }

    func requestFocus() {
        focusRequested = true
    }

    func clearFocusRequest() {
        focusRequested = false
    }

    @MainActor
    func send() async {
        guard let bridge else { return }
        await send(bridge: bridge)
    }

    @MainActor
    func send(bridge: OrbitBridgeProtocol) async {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        errorMessage = nil
        inputText = ""
        messages.append(ChatMessage(role: .user, content: query))
        isStreaming = true
        var assistant = ChatMessage(role: .assistant, content: "")
        messages.append(assistant)
        let assistantID = assistant.id
        do {
            for try await chunk in bridge.chatStream(query) {
                switch chunk.kind {
                case .text(let delta):
                    assistant.content += delta
                    replaceMessage(id: assistantID, with: assistant)
                case .sources(let hits):
                    assistant.sourceAtoms = hits
                    replaceMessage(id: assistantID, with: assistant)
                case .done:
                    break
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isStreaming = false
    }

    private func replaceMessage(id: UUID, with message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index] = message
    }
}
