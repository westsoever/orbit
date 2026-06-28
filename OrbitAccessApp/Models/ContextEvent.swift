import Foundation
import GRDB

struct ContextEvent: Codable, FetchableRecord, TableRecord, Identifiable, Sendable {
    static let databaseTableName = "context_events"
    let id: Int64
    let timestamp: String
    let appBundleId: String?
    let appName: String?
    let windowTitle: String?
    let focusedElementRole: String?
    let focusedElementLabel: String?
    let visibleText: String?
    let rawJson: String?
    let captureMethod: String?
    let captureTier: Int?
    let pageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case appBundleId = "app_bundle_id"
        case appName = "app_name"
        case windowTitle = "window_title"
        case focusedElementRole = "focused_element_role"
        case focusedElementLabel = "focused_element_label"
        case visibleText = "visible_text"
        case rawJson = "raw_json"
        case captureMethod = "capture_method"
        case captureTier = "capture_tier"
        case pageUrl = "page_url"
    }
}
