import SwiftUI

extension ReadingPreferences {
    /// Theme used for nav bar / tab bar / tables (maps light/dark/sepia).
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
