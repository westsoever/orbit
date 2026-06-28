import Foundation

protocol OrbitBridgeProtocol: Sendable {
    var isDaemonAlive: Bool { get }
    func checkStatus() async -> Bool
    func requestShutdown() async throws
    func fetchPendingTasks() async -> [TaskLogEntry]
    func approve(id: Int64, prompt: String) async throws
    func skip(id: Int64) async throws
    func search(_ query: String, limit: Int) async -> [SearchHit]
    func chatStream(_ query: String) -> AsyncThrowingStream<ChatChunk, Error>
}

enum OrbitBridgeError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case daemonOffline

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Orbit daemon."
        case .httpStatus(let code): return "Orbit daemon returned HTTP \(code)."
        case .daemonOffline: return "Orbit daemon is offline."
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
