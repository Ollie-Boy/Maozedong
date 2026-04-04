import SwiftUI

struct ReadingPreferences: Codable, Equatable {
    var fontSize: Double = 18
    var lineSpacing: Double = 7
    var theme: Theme = .sepia

    enum Theme: String, CaseIterable, Codable, Identifiable {
        case light
        case dark
        case sepia

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .light:
                return "浅色"
            case .dark:
                return "深色"
            case .sepia:
                return "护眼"
            }
        }

        var backgroundColor: Color {
            switch self {
            case .light:
                return Color.white
            case .dark:
                return Color.black
            case .sepia:
                return Color(red: 0.96, green: 0.93, blue: 0.86)
            }
        }

        var textColor: Color {
            switch self {
            case .light, .sepia:
                return Color.black
            case .dark:
                return Color.white
            }
        }
    }

    var backgroundColor: Color {
        theme.backgroundColor
    }

    var textColor: Color {
        theme.textColor
    }
}

extension ReadingPreferences {
    static let `default` = ReadingPreferences()
}
