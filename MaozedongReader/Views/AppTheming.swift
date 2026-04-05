import SwiftUI

extension ReadingPreferences.Theme {
    /// Drives system chrome (status bar icons, etc.) to match reading theme.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light, .sepia: return .light
        case .dark: return .dark
        }
    }
}

extension ReadingPreferences {
    /// Slightly distinct from page background for grouped list rows.
    var listRowBackgroundColor: Color {
        switch theme {
        case .light:
            return Color(white: 0.99)
        case .dark:
            return Color(white: 0.11)
        case .sepia:
            return Color(red: 0.99, green: 0.96, blue: 0.90)
        }
    }
}
