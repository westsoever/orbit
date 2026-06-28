import Foundation
import Observation
import Combine

@Observable
final class TaskStore {
    var pendingTasks: [TaskLogEntry] = []
    var isLoading = false

    @ObservationIgnored private var timer: AnyCancellable?
    @ObservationIgnored private var bridge: OrbitBridgeProtocol?
    @ObservationIgnored private var dbReader: OrbitDBReader?
    @ObservationIgnored private var liveServicesCheck: () -> Bool = { false }

    func configure(bridge: OrbitBridgeProtocol, dbReader: OrbitDBReader) {
        self.bridge = bridge
        self.dbReader = dbReader
    }

    func startPolling(bridge: OrbitBridgeProtocol, liveServicesCheck: @escaping () -> Bool) {
        self.bridge = bridge
        self.liveServicesCheck = liveServicesCheck
        timer?.cancel()
        timer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refresh(isDaemonOnline: self?.liveServicesCheck() ?? false) }
            }
    }

    @MainActor
    func refresh(isDaemonOnline: Bool) async {
        isLoading = true
        defer { isLoading = false }

        if isDaemonOnline, let bridge {
            pendingTasks = await bridge.fetchPendingTasks()
            return
        }

        if let dbReader, dbReader.isReady {
            pendingTasks = (try? dbReader.fetchPendingTasksToday()) ?? []
        } else {
            pendingTasks = []
        }
    }

    @MainActor
    func approve(task: TaskLogEntry, prompt: String) async throws {
        guard let bridge else { return }
        try await bridge.approve(id: task.id, prompt: prompt)
        await refresh(isDaemonOnline: liveServicesCheck())
    }

    @MainActor
    func approve(id: Int64, prompt: String, bridge: OrbitBridgeProtocol) async {
        do {
            try await bridge.approve(id: id, prompt: prompt)
            await refresh(isDaemonOnline: liveServicesCheck())
        } catch {
            // UI layer may surface errors later.
        }
    }

    @MainActor
    func skip(task: TaskLogEntry) async throws {
        guard let bridge else { return }
        try await bridge.skip(id: task.id)
        await refresh(isDaemonOnline: liveServicesCheck())
    }

    @MainActor
    func skip(id: Int64, bridge: OrbitBridgeProtocol) async {
        do {
            try await bridge.skip(id: id)
            await refresh(isDaemonOnline: liveServicesCheck())
        } catch {
            // UI layer may surface errors later.
        }
    }
}
