import Foundation

final class OrbitBridgeClient: OrbitBridgeProtocol, @unchecked Sendable {
    private let base = URL(string: "http://127.0.0.1:8765")!
    private let session: URLSession
    private(set) var isDaemonAlive = false
    private(set) var captureActive = false

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func checkStatus() async -> Bool {
        do {
            let request = URLRequest(url: base.appendingPathComponent("/api/status"))
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                isDaemonAlive = false
                return false
            }
            let status = try JSONDecoder().decode(DaemonStatusResponse.self, from: data)
            isDaemonAlive = status.ok
            captureActive = status.captureActive ?? false
            return status.ok
        } catch {
            isDaemonAlive = false
            captureActive = false
            return false
        }
    }

    func fetchPendingTasks() async -> [TaskLogEntry] {
        guard await checkStatus() else { return [] }
        do {
            let request = URLRequest(url: base.appendingPathComponent("/api/tasks/pending"))
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            let decoded = try JSONDecoder().decode(PendingTasksResponse.self, from: data)
            return decoded.tasks
        } catch {
            return []
        }
    }

    func approve(id: Int64, prompt: String) async throws {
        try await postTaskAction(id: id, pathSuffix: "approve", body: ApproveTaskBody(approvedPrompt: prompt))
    }

    func skip(id: Int64) async throws {
        try await postTaskAction(id: id, pathSuffix: "skip", body: Optional<String>.none)
    }

    func search(_ query: String, limit: Int = 20) async -> [SearchHit] {
        guard await checkStatus() else { return [] }
        var components = URLComponents(url: base.appendingPathComponent("/api/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components.url else { return [] }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            if let hits = try? JSONDecoder().decode([SearchHit].self, from: data) {
                return hits
            }
            let wrapped = try JSONDecoder().decode(SearchResponse.self, from: data)
            return wrapped.hits
        } catch {
            return []
        }
    }

    func chatStream(_ query: String) -> AsyncThrowingStream<ChatChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: base.appendingPathComponent("/api/chat"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.httpBody = try JSONEncoder().encode(["query": query])
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        throw OrbitBridgeError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" {
                            continuation.yield(ChatChunk(kind: .done))
                            break
                        }
                        if let chunk = Self.decodeSSEChunk(payload) {
                            continuation.yield(chunk)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func postTaskAction<T: Encodable>(id: Int64, pathSuffix: String, body: T?) async throws {
        guard await checkStatus() else { throw OrbitBridgeError.daemonOffline }
        var request = URLRequest(url: base.appendingPathComponent("/api/task/\(id)/\(pathSuffix)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OrbitBridgeError.invalidResponse
        }
    }

    private static func decodeSSEChunk(_ payload: String) -> ChatChunk? {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let text = json["text"] as? String {
            return ChatChunk(kind: .text(text))
        }
        if let hitsData = json["hits"],
           let data = try? JSONSerialization.data(withJSONObject: hitsData),
           let hits = try? JSONDecoder().decode([SearchHit].self, from: data) {
            return ChatChunk(kind: .sources(hits))
        }
        return nil
    }
}
