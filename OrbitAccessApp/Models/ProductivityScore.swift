import Foundation

struct ScoreInputs: Sendable {
    let taskCompletion: Double
    let focusDepth: Double
    let contextRichness: Double
    let captureConsistency: Double
}

struct ProductivityScore: Sendable {
    let value: Double
    let inputs: ScoreInputs

    init(inputs: ScoreInputs) {
        self.inputs = inputs
        self.value = productivityScore(inputs)
    }
}

func productivityScore(_ inputs: ScoreInputs) -> Double {
    let raw = 0.35 * inputs.taskCompletion
        + 0.25 * inputs.focusDepth
        + 0.20 * inputs.contextRichness
        + 0.20 * inputs.captureConsistency
    return (raw * 10).rounded(toPlaces: 1)
}

struct HourSlot: Identifiable, Sendable {
    let hour: String
    let appName: String
    let eventCount: Int

    var id: String { "\(hour)-\(appName)" }
    var hourLabel: String { "\(hour):00" }
}

struct RoutineBlock: Identifiable, Sendable {
    let id: String
    let title: String
    let startTime: String
    let endTime: String
    let isActiveNow: Bool

    init(id: String, title: String, startTime: String, endTime: String, isActiveNow: Bool = false) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.isActiveNow = isActiveNow
    }

    var timeRange: String { "\(startTime) – \(endTime)" }
}

extension RoutineBlock: Codable {}
