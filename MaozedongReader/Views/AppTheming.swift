import SwiftUI

extension ReadingPreferences.Theme {
    /// Drives system chrome when not using `followSystemAppearance` / night auto.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light, .sepia: return .light
        case .dark: return .dark
        }
    }
}

extension ReadingPreferences {
    /// Match page background so grouped list rows do not show as bright white cards (esp. newer iOS).
    var listRowBackgroundColor: Color {
        backgroundColor
    }

    /// Soft top color for library ambient gradient (pairs with `libraryGradientBottom`).
    var libraryGradientTop: Color {
        switch theme {
        case .light:
            return Color(red: 0.99, green: 0.98, blue: 0.97)
        case .dark:
            return Color(red: 0.12, green: 0.11, blue: 0.14)
        case .sepia:
            if sepiaWarmTint {
                return Color(red: 0.97, green: 0.93, blue: 0.82)
            }
            return Color(red: 0.98, green: 0.95, blue: 0.88)
        }
    }

    var libraryGradientBottom: Color {
        switch theme {
        case .light:
            return Color(red: 0.94, green: 0.95, blue: 0.98)
        case .dark:
            return Color(red: 0.06, green: 0.06, blue: 0.08)
        case .sepia:
            if sepiaWarmTint {
                return Color(red: 0.90, green: 0.86, blue: 0.74)
            }
            return Color(red: 0.93, green: 0.90, blue: 0.82)
        }
    }

    /// Thin accent for section markers / card strokes (not loud).
    var libraryAccentColor: Color {
        switch theme {
        case .light:
            return Color(red: 0.75, green: 0.22, blue: 0.18)
        case .dark:
            return Color(red: 0.95, green: 0.72, blue: 0.45)
        case .sepia:
            return Color(red: 0.58, green: 0.26, blue: 0.16)
        }
    }
}
