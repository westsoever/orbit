import Foundation

enum SidebaneSection: String, CaseIterable, Identifiable {
    case search
    case agents
    case capture
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: return "SEARCH"
        case .agents: return "AGENTS"
        case .capture: return "CAPTURE"
        case .privacy: return "PRIVACY"
        }
    }
}

struct AIFunctionContext {
    let searchStore: SearchStore
    let chatStore: ChatStore
    let canBrowseContext: Bool
    let canUseLiveServices: Bool

    @MainActor
    func prefillChat(_ text: String) {
        chatStore.inputText = text
        chatStore.requestFocus()
    }

    @MainActor
    func requestChatFocus() {
        chatStore.requestFocus()
    }
}

protocol AIFunction: Identifiable {
    var id: String { get }
    var title: String { get }
    var icon: String { get }
    var section: SidebaneSection { get }
    func execute(_ context: AIFunctionContext) async
}
