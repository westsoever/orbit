import Foundation

protocol OrbitBridgeProtocol: Sendable {
    var isDaemonAlive: Bool { get }
    func checkStatus() async -> Bool
    func requestShutdown() async throws
    func fetchPendingTasks() async -> [TaskLogEntry]
    func fetchKanbanTasks() async -> [TaskLogEntry]
    func detectTasks(refresh: Bool) async throws -> TaskDetectResult
    func approve(id: Int64, prompt: String) async throws
    func skip(id: Int64) async throws
    func search(_ query: String, limit: Int) async -> [SearchHit]
    func chatStream(_ query: String) -> AsyncThrowingStream<ChatChunk, Error>
}

struct TaskDetectResult: Sendable {
    let tasks: [TaskLogEntry]
    let message: String
}

enum OrbitBridgeError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case serverMessage(String)
    case daemonOffline

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Orbit returned an unexpected response. Try restarting the daemon from the sidebar."
        case .httpStatus(let code):
            switch code {
            case 503:
                return "Orbit could not answer right now. Check that AI is configured (Cloud AI, an API key in ~/.orbit/.env, or a local Ollama model)."
            case 502, 504:
                return "Orbit timed out while generating an answer. Try a shorter question or check your AI provider."
            default:
                return "Orbit daemon returned an error (HTTP \(code)). Try restarting the daemon."
            }
        case .serverMessage(let message):
            return ChatErrorFormatter.relayRegistrationMessage(message)
        case .daemonOffline:
            return "Orbit's background service is not responding. It starts automatically with the app — quit and reopen Orbit if this persists."
        }
    }
}

struct DaemonStatusResponse: Decodable, Sendable {
    let ok: Bool
    let captureActive: Bool?

    enum CodingKeys: String, CodingKey {
        case ok
        case captureActive = "capture_active"
    }
}

struct SearchResponse: Decodable, Sendable {
    let hits: [SearchHit]
}

struct PendingTasksResponse: Decodable, Sendable {
    let tasks: [TaskLogEntry]

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let array = try? container.decode([TaskLogEntry].self) {
            tasks = array
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeIfPresent([TaskLogEntry].self, forKey: .tasks) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case tasks
    }
}

struct ApproveTaskBody: Encodable {
    let approvedPrompt: String

    enum CodingKeys: String, CodingKey {
        case approvedPrompt = "approved_prompt"
    }
}

struct KanbanTasksResponse: Decodable, Sendable {
    let tasks: [TaskLogEntry]
}

struct TaskDetectResponse: Decodable, Sendable {
    let tasks: [TaskLogEntry]
    let source: String?
    let count: Int?
}

struct TaskDetectRequest: Encodable, Sendable {
    let refresh: Bool
    let hours: Int
}
