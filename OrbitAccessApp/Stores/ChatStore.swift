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
    func send(canUseLiveServices: Bool, canSearchLocally: Bool, hasDatabase: Bool) async {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        if canUseLiveServices, let bridge {
            await sendViaBridge(
                bridge: bridge,
                query: query,
                fallbackOffline: canSearchLocally,
                dbReader: dbReader
            )
        } else if canSearchLocally, let dbReader {
            await sendOffline(query: query, dbReader: dbReader)
        } else {
            errorMessage = ChatErrorFormatter.noChatAvailable(
                hasDatabase: hasDatabase,
                hasDaemon: canUseLiveServices
            )
        }
    }

    @MainActor
    private func sendViaBridge(
        bridge: OrbitBridgeProtocol,
        query: String,
        fallbackOffline: Bool,
        dbReader: OrbitDBReader?
    ) async {
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
            if assistant.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                removeMessage(id: assistantID)
                errorMessage = "Orbit did not return an answer. Check your AI setup and try again."
            }
        } catch {
            removeMessage(id: assistantID)
            if fallbackOffline, let dbReader, ChatErrorFormatter.isMissingCredentials(error) {
                await sendOffline(
                    query: query,
                    dbReader: dbReader,
                    includeUserMessage: false,
                    preamble: "AI is not configured yet — showing keyword matches from your saved context instead."
                )
            } else {
                errorMessage = ChatErrorFormatter.userMessage(for: error)
            }
        }
        isStreaming = false
    }

    @MainActor
    private func sendOffline(
        query: String,
        dbReader: OrbitDBReader,
        includeUserMessage: Bool = true,
        preamble: String? = nil
    ) async {
        errorMessage = nil
        if includeUserMessage {
            inputText = ""
            messages.append(ChatMessage(role: .user, content: query))
        }
        isStreaming = true

        let hits: [SearchHit]
        do {
            hits = try dbReader.lexicalSearch(query, limit: 8)
        } catch {
            hits = []
            errorMessage = "Could not search your saved context: \(ChatErrorFormatter.userMessage(for: error))"
        }

        let body: String
        if hits.isEmpty {
            body = "No matching context found in your local history. Start the daemon to capture new activity or try different keywords."
        } else {
            body = formatOfflineContext(hits)
                + "\n\n_(Offline mode — keyword matches only. Enable Cloud AI, add an API key, or run Ollama for full answers.)_"
        }
        let content = [preamble, body].compactMap { $0 }.joined(separator: "\n\n")
        let assistant = ChatMessage(role: .assistant, content: content, sourceAtoms: hits)
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

    private func removeMessage(id: UUID) {
        messages.removeAll { $0.id == id }
    }
}
