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
}
