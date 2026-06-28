import Foundation
import Observation
import Combine

@Observable
final class TaskStore {
    var pendingTasks: [TaskLogEntry] = []
    var isLoading = false

    @ObservationIgnored private var timer: AnyCancellable?
    @ObservationIgnored private var bridge: OrbitBridgeProtocol?

    func configure(bridge: OrbitBridgeProtocol) {
        self.bridge = bridge
    }

    func startPolling(_ bridge: OrbitBridgeProtocol) {
        self.bridge = bridge
        timer?.cancel()
        timer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
    }

    @MainActor
    func refresh() async {
        guard let bridge else { return }
        isLoading = true
        pendingTasks = await bridge.fetchPendingTasks()
        isLoading = false
    }

    @MainActor
    func approve(task: TaskLogEntry, prompt: String) async throws {
        guard let bridge else { return }
        try await bridge.approve(id: task.id, prompt: prompt)
        await refresh()
    }

    @MainActor
    func approve(id: Int64, prompt: String, bridge: OrbitBridgeProtocol) async {
        do {
            try await bridge.approve(id: id, prompt: prompt)
            await refresh()
        } catch {
            // UI layer may surface errors later.
        }
    }

    @MainActor
    func skip(task: TaskLogEntry) async throws {
        guard let bridge else { return }
        try await bridge.skip(id: task.id)
        await refresh()
    }

    @MainActor
    func skip(id: Int64, bridge: OrbitBridgeProtocol) async {
        do {
            try await bridge.skip(id: id)
            await refresh()
        } catch {
            // UI layer may surface errors later.
        }
    }
}
