import Foundation
import Observation
import Combine

@Observable
final class InsightStore {
    var productivityScore = ProductivityScore(
        inputs: ScoreInputs(taskCompletion: 0, focusDepth: 0, contextRichness: 0, captureConsistency: 0)
    )
    var schedule: [HourSlot] = []
    var scheduleSlots: [HourSlot] {
        schedule
    }
    var routines: [RoutineBlock] = []
    var recentCaptures: [ContextEvent] = []
    var atomsCapturedToday = 0

    @ObservationIgnored private var aggregateTimer: AnyCancellable?
    @ObservationIgnored private var dbReader: OrbitDBReader?
    @ObservationIgnored private var lastSeenEventId: Int64 = 0

    func configure(dbReader: OrbitDBReader) {
        self.dbReader = dbReader
        routines = RoutineStorage.load()
    }

    func startAggregatePolling() {
        aggregateTimer?.cancel()
        aggregateTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshAggregates()
            }
    }

    func refreshAggregates() {
        guard let dbReader, dbReader.isReady else { return }
        if let inputs = try? dbReader.computeScoreInputs() {
            productivityScore = ProductivityScore(inputs: inputs)
        }
        schedule = (try? dbReader.fetchDailySchedule()) ?? []
        atomsCapturedToday = (try? dbReader.atomsCapturedToday()) ?? 0
    }

    @MainActor
    func refreshAggregates(reader: OrbitDBReader) async {
        configure(dbReader: reader)
        refreshAggregates()
    }

    func refreshRecentCaptures(incremental: Bool) {
        guard let dbReader, dbReader.isReady else { return }
        if incremental, lastSeenEventId > 0 {
            let newEvents = (try? dbReader.fetchRecentCaptures(afterId: lastSeenEventId)) ?? []
            if !newEvents.isEmpty {
                recentCaptures = Array((newEvents + recentCaptures).prefix(10))
                lastSeenEventId = recentCaptures.map(\.id).max() ?? lastSeenEventId
            }
            return
        }
        recentCaptures = (try? dbReader.fetchRecentCapturesTail()) ?? []
        lastSeenEventId = recentCaptures.map(\.id).max() ?? 0
    }
}
