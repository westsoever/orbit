import Foundation
import GRDB

struct TextAtom: Codable, FetchableRecord, TableRecord, Identifiable, Sendable {
    static let databaseTableName = "text_atoms"
    let id: Int64
    let eventId: Int64
    let role: String
    let label: String?
    let text: String
    let elementPath: String
    let elementHash: String?

    enum CodingKeys: String, CodingKey {
        case id, role, label, text
        case eventId = "event_id"
        case elementPath = "element_path"
        case elementHash = "element_hash"
    }
}
