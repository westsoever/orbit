import Foundation
import Observation
import Combine

@Observable
final class AppViewModel {
    let chatStore = ChatStore()
    let taskStore = TaskStore()
    let searchStore = SearchStore()
    let insightStore = InsightStore()

    var isDaemonOnline = false
    var isCaptureActive = false
    var isDatabaseReady = false
    var bootstrapError: String?

    let bridge = OrbitBridgeClient()
    let dbReader = OrbitDBReader()

    @ObservationIgnored private let walWatcher = WALWatcher()
    @ObservationIgnored private var statusTimer: AnyCancellable?

    init() {
        chatStore.configure(bridge: bridge)
        taskStore.configure(bridge: bridge)
        searchStore.configure(bridge: bridge, dbReader: dbReader)
        insightStore.configure(dbReader: dbReader)
    }

    @MainActor
    func start() async {
        do {
            try await dbReader.bootstrap()
            isDatabaseReady = true
            insightStore.refreshAggregates()
            insightStore.refreshRecentCaptures(incremental: false)
            startWALWatcher()
        } catch {
            bootstrapError = error.localizedDescription
        }
        startStatusPolling()
        taskStore.startPolling(bridge)
        insightStore.startAggregatePolling()
    }

    @MainActor
    func retryDatabaseBootstrap() async {
        bootstrapError = nil
        do {
            try await dbReader.bootstrap()
            isDatabaseReady = true
            insightStore.refreshAggregates()
            insightStore.refreshRecentCaptures(incremental: false)
            startWALWatcher()
        } catch {
            bootstrapError = error.localizedDescription
            isDatabaseReady = false
        }
    }

    @MainActor
    func startDaemonPolling() async {
        await pollDaemonStatus()
    }

    @MainActor
    func aiContext() -> AIFunctionContext {
        AIFunctionContext(searchStore: searchStore, chatStore: chatStore, isDaemonOnline: isDaemonOnline)
    }

    private func startStatusPolling() {
        statusTimer?.cancel()
        statusTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.pollDaemonStatus() }
            }
        Task { await pollDaemonStatus() }
    }

    @MainActor
    private func pollDaemonStatus() async {
        isDaemonOnline = await bridge.checkStatus()
        isCaptureActive = bridge.captureActive
    }

    private func startWALWatcher() {
        guard let walURL = dbReader.walURL() else { return }
        walWatcher.start(walURL: walURL) { [weak self] in
            Task { @MainActor in
                self?.insightStore.refreshRecentCaptures(incremental: true)
                self?.insightStore.refreshAggregates()
            }
        }
    }
}
