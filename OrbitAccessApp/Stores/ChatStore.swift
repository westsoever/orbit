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
    @ObservationIgnored private var dbReader: OrbitDBReader?

    func configure(bridge: OrbitBridgeProtocol, dbReader: OrbitDBReader) {
        self.bridge = bridge
        self.dbReader = dbReader
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
    func send(canUseAIChat: Bool, canSearchLocally: Bool) async {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        if canUseAIChat, let bridge {
            await send(bridge: bridge)
        } else if canSearchLocally, let dbReader {
            await sendOffline(query: query, dbReader: dbReader)
        } else {
            errorMessage = "Start Orbit to enable chat — no AI service and no local database are available yet."
        }
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

    @MainActor
    private func sendOffline(query: String, dbReader: OrbitDBReader) async {
        errorMessage = nil
        inputText = ""
        messages.append(ChatMessage(role: .user, content: query))
        isStreaming = true

        let hits = (try? dbReader.lexicalSearch(query, limit: 8)) ?? []
        let body: String
        if hits.isEmpty {
            body = "No matching context found in your local history. Start the daemon to capture new activity or try different keywords."
        } else {
            body = formatOfflineContext(hits)
                + "\n\n_(Offline mode — keyword matches only. Start the daemon for AI answers.)_"
        }

        var assistant = ChatMessage(role: .assistant, content: body, sourceAtoms: hits)
        messages.append(assistant)
        isStreaming = false
    }

    /// Context format copied from orbit/browser_bridge/server.py _build_chat_context
    private func formatOfflineContext(_ hits: [SearchHit]) -> String {
        hits.enumerated().map { index, hit in
            "[\(index + 1)] \(hit.appName) — \(hit.windowTitle ?? "untitled")\n\(hit.snippetHtml)"
        }.joined(separator: "\n\n")
    }

    private func replaceMessage(id: UUID, with message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index] = message
    }
}
