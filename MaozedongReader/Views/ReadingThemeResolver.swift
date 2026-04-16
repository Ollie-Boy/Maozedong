import SwiftUI

extension ReadingPreferences {
    /// Resolved theme for navigation and list chrome.
    func resolvedChromeTheme(environmentScheme: ColorScheme) -> Theme {
        if theme == .sepia { return .sepia }
        if followSystemAppearance {
            return environmentScheme == .dark ? .dark : .light
        }
        if autoDarkAtNight {
            let h = Calendar.current.component(.hour, from: Date())
            if h >= 22 || h < 7 { return .dark }
        }
        return theme
    }

    func preferredColorSchemeResolved(environmentScheme: ColorScheme) -> ColorScheme? {
        if theme == .sepia { return .light }
        if followSystemAppearance { return nil }
        if autoDarkAtNight {
            let h = Calendar.current.component(.hour, from: Date())
            if h >= 22 || h < 7 { return .dark }
        }
        return theme == .dark ? .dark : .light
    }
}
