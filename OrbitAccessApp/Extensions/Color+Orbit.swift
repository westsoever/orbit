import SwiftUI

extension Color {
    static let orbitAccent = Color(hex: 0x636AFF)
    static let orbitCardDark = Color(hex: 0x1C1C1E)
    static let orbitCardLight = Color.white
    static let orbitCardBorderDark = Color(hex: 0x2C2C2E)
    static let orbitCardBorderLight = Color(hex: 0xE5E5EA)
    static let orbitSecondaryTextDark = Color(hex: 0x8E8E93)
    static let orbitSecondaryTextLight = Color(hex: 0x6D6D72)

    static let orbitChatBackgroundLight = Color(hex: 0xF9F8F3)
    static let orbitChatBackgroundDark = Color(hex: 0x141414)

    static func orbitChatBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .orbitChatBackgroundDark : .orbitChatBackgroundLight
    }

    static let orbitScoreRed = Color(hex: 0xEF4444)
    static let orbitScoreAmber = Color(hex: 0xF59E0B)
    static let orbitScoreLime = Color(hex: 0x84CC16)
    static let orbitScoreEmerald = Color(hex: 0x10B981)

    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    static func orbitSecondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .orbitSecondaryTextDark : .orbitSecondaryTextLight
    }

    static func orbitScoreColor(for score: Double) -> Color {
        switch score {
        case ..<5: return .orbitScoreRed
        case ..<7: return .orbitScoreAmber
        case ..<8.5: return .orbitScoreLime
        default: return .orbitScoreEmerald
        }
    }

    static func orbitScoreLabel(for score: Double) -> String {
        switch score {
        case ..<5: return "Needs improvement"
        case ..<7: return "Moderate"
        case ..<8.5: return "Good"
        default: return "Excellent"
        }
    }
}
