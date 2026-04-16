import SwiftUI

extension ReadingPreferences.Theme {
    /// Color scheme for system chrome when theme is manual.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light, .sepia: return .light
        case .dark: return .dark
        }
    }
}

extension ReadingPreferences {
    /// List row background aligned with page background.
    var listRowBackgroundColor: Color {
        backgroundColor
    }

    /// Library gradient top color.
    var libraryGradientTop: Color {
        switch theme {
        case .light:
            return Color(red: 0.93, green: 0.965, blue: 0.995)
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
            return Color(red: 0.99, green: 0.995, blue: 1.0)
        case .dark:
            return Color(red: 0.06, green: 0.06, blue: 0.08)
        case .sepia:
            if sepiaWarmTint {
                return Color(red: 0.90, green: 0.86, blue: 0.74)
            }
            return Color(red: 0.93, green: 0.90, blue: 0.82)
        }
    }

    /// Accent for section markers and card strokes.
    var libraryAccentColor: Color {
        switch theme {
        case .light:
            return Color(red: 0.28, green: 0.58, blue: 0.96)
        case .dark:
            return Color(red: 0.95, green: 0.72, blue: 0.45)
        case .sepia:
            return Color(red: 0.58, green: 0.26, blue: 0.16)
        }
    }

    /// Search field fill on list background.
    var searchFieldFill: Color {
        switch theme {
        case .light:
            return Color.white.opacity(0.88)
        case .dark:
            return Color(white: 0.16)
        case .sepia:
            return Color.white.opacity(0.55)
        }
    }

    var searchFieldStroke: Color {
        switch theme {
        case .light:
            return Color.black.opacity(0.18)
        case .dark:
            return Color.white.opacity(0.28)
        case .sepia:
            return Color.black.opacity(0.22)
        }
    }
}

extension View {
    /// Rounded rect chrome for inline search fields.
    func searchQueryFieldChrome(_ preferences: ReadingPreferences) -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(preferences.searchFieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(preferences.searchFieldStroke, lineWidth: 1.25)
            )
    }
}
