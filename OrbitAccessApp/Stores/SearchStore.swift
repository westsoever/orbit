import Foundation
import Observation

enum SearchMode: String, Sendable {
    case lexical
    case hybrid
}

enum SearchTier: Sendable {
    case none
    case lexical
    case hybrid
}

@Observable
final class SearchStore {
    var hits: [SearchHit] = []
    var query = ""
    var mode: SearchMode = .hybrid
    var searchTier: SearchTier = .none
    var isSearching = false
    var lastError: String?
    var panelActive = false

    @ObservationIgnored private var bridge: OrbitBridgeProtocol?
    @ObservationIgnored private var dbReader: OrbitDBReader?

    func configure(bridge: OrbitBridgeProtocol, dbReader: OrbitDBReader) {
        self.bridge = bridge
        self.dbReader = dbReader
    }

    func activateSemanticSearch() {
        mode = .hybrid
        query = ""
        panelActive = true
        lastError = nil
    }

    func activateFindByApp() {
        mode = .lexical
        query = ""
        panelActive = true
        lastError = nil
    }

    func activateFindByTime() {
        mode = .lexical
        query = "time: "
        panelActive = true
        lastError = nil
    }

    @MainActor
    func search(canUseLiveServices: Bool, canSearchLocally: Bool) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hits = []
            lastError = nil
            searchTier = .none
            return
        }
        isSearching = true
        lastError = nil
        defer { isSearching = false }
        panelActive = true

        guard canSearchLocally, dbReader != nil else {
            hits = []
            searchTier = .none
            lastError = "Orbit database is not available."
            return
        }

        if canUseLiveServices, mode == .hybrid, let bridge {
            let hybridHits = await bridge.search(trimmed, limit: 20)
            if !hybridHits.isEmpty {
                hits = hybridHits
                searchTier = .hybrid
                return
            }
        }

        guard let dbReader else {
            hits = []
            searchTier = .none
            lastError = "Orbit database is not available."
            return
        }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("time:") || lower.hasPrefix("find by time:") {
            let hourPart = trimmed.split(separator: ":", maxSplits: 1).dropFirst().joined(separator: ":")
                .trimmingCharacters(in: .whitespaces)
            hits = (try? dbReader.fetchAtomsByHour(hourPart.isEmpty ? nil : hourPart, limit: 20)) ?? []
        } else if lower.hasPrefix("find in app:") {
            let app = trimmed.replacingOccurrences(
                of: "(?i)find in app:\\s*",
                with: "",
                options: .regularExpression
            )
            hits = (try? dbReader.fetchAtomsByApp(app, limit: 20)) ?? []
        } else {
            hits = (try? dbReader.lexicalSearch(trimmed, limit: 20)) ?? []
        }

        searchTier = .lexical

        if hits.isEmpty {
            lastError = "No matches for \"\(trimmed)\"."
        }
    }
}
