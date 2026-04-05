import SwiftUI
import UIKit

/// Opaque `UITabBar` behind SwiftUI `TabView` page style so the home-indicator area matches the theme.
enum AppAppearanceUIKit {
    static func syncTabBar(with theme: ReadingPreferences.Theme) {
        let bg: UIColor
        switch theme {
        case .light:
            bg = .systemBackground
        case .dark:
            bg = .black
        case .sepia:
            bg = UIColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 1)
        }
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = bg
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
