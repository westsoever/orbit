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

    /// Historical data available from ~/.orbit/orbit.db
    var canBrowseContext: Bool { isDatabaseReady && dbReader.isReady }

    /// Hybrid search, LLM chat, capture indicator, task dispatch
    var canUseLiveServices: Bool { isDaemonOnline }

    /// Lexical search + offline snippet chat
    var canSearchLocally: Bool { canBrowseContext }

    /// AI streaming chat via bridge
    var canUseAIChat: Bool { canUseLiveServices }
    var bootstrapFailure: OrbitDBError?
    var daemonControlState: DaemonControlState = .offline

    var seriousIssue: OrbitIssue? {
        guard let failure = bootstrapFailure else { return nil }
        return .databaseBootstrapFailed(message: failure.localizedDescription)
    }

    let bridge = OrbitBridgeClient()
    let dbReader = OrbitDBReader()
    private let daemonManager: DaemonManager

    @ObservationIgnored private let walWatcher = WALWatcher()
    @ObservationIgnored private var statusTimer: AnyCancellable?

    init() {
        daemonManager = DaemonManager(bridge: bridge)
        chatStore.configure(bridge: bridge, dbReader: dbReader)
        taskStore.configure(bridge: bridge, dbReader: dbReader)
        searchStore.configure(bridge: bridge, dbReader: dbReader)
        insightStore.configure(dbReader: dbReader)
    }

    @MainActor
    func start() async {
        do {
            try await dbReader.bootstrap()
            bootstrapFailure = nil
            isDatabaseReady = true
            insightStore.refreshAggregates()
            insightStore.refreshRecentCaptures(incremental: false)
            startWALWatcher()
        } catch let error as OrbitDBError {
            bootstrapFailure = error
        } catch {
            bootstrapFailure = .databaseUnavailable
        }
        startStatusPolling()
        taskStore.startPolling(bridge: bridge) { [weak self] in
            self?.canUseLiveServices ?? false
        }
        insightStore.startAggregatePolling()
    }

    @MainActor
    func retryDatabaseBootstrap() async {
        bootstrapFailure = nil
        do {
            try await dbReader.bootstrap()
            bootstrapFailure = nil
            isDatabaseReady = true
            insightStore.refreshAggregates()
            insightStore.refreshRecentCaptures(incremental: false)
            startWALWatcher()
        } catch let error as OrbitDBError {
            bootstrapFailure = error
            isDatabaseReady = false
        } catch {
            bootstrapFailure = .databaseUnavailable
            isDatabaseReady = false
        }
    }

    @MainActor
    func startDaemon() async {
        do {
            try await daemonManager.start()
            daemonControlState = daemonManager.controlState
            await pollDaemonStatus()
        } catch {
            daemonControlState = daemonManager.controlState
        }
    }

    @MainActor
    func stopDaemon() async {
        do {
            try await daemonManager.stop()
            daemonControlState = daemonManager.controlState
            await pollDaemonStatus()
        } catch {
            daemonControlState = daemonManager.controlState
        }
    }

    @MainActor
    func aiContext() -> AIFunctionContext {
        AIFunctionContext(
            searchStore: searchStore,
            chatStore: chatStore,
            canBrowseContext: canBrowseContext,
            canUseLiveServices: canUseLiveServices
        )
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
        daemonManager.syncControlState(isOnline: isDaemonOnline, isCaptureActive: isCaptureActive)
        daemonControlState = daemonManager.controlState
        await taskStore.refresh(isDaemonOnline: isDaemonOnline)
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
