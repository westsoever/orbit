import Foundation

enum OrbitIssue: Equatable, Identifiable {
    case databaseBootstrapFailed(message: String)

    var id: String {
        switch self {
        case .databaseBootstrapFailed(let message):
            return "db-bootstrap-\(message)"
        }
    }

    var message: String {
        switch self {
        case .databaseBootstrapFailed(let message):
            return message
        }
    }

    var actionTitle: String? {
        switch self {
        case .databaseBootstrapFailed:
            return "Select orbit.db"
        }
    }
}
