import SwiftUI

extension AgentType {
    var color: Color {
        switch self {
        case .writing: return Color(hex: 0x4A90E2)
        case .research: return Color(hex: 0x9B59B6)
        case .code: return Color(hex: 0x27AE60)
        case .admin: return Color(hex: 0xE67E22)
        case .data: return Color(hex: 0x00B5D8)
        case .communication: return Color(hex: 0x5B73E8)
        }
    }

    var icon: String {
        switch self {
        case .writing: return "pencil.line"
        case .research: return "magnifyingglass"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .admin: return "gearshape"
        case .data: return "chart.bar"
        case .communication: return "bubble.left.and.bubble.right"
        }
    }

    var displayName: String { rawValue.capitalized }
    var chatTemplate: String { "\(displayName): " }
}
