import SwiftUI
import UIKit

/// Global UIKit chrome so navigation, search bars, and TabView footers match the reading theme.
enum AppAppearanceUIKit {
    static func syncGlobalChrome(preferences: ReadingPreferences, environmentScheme: ColorScheme) {
        let theme = preferences.resolvedChromeTheme(environmentScheme: environmentScheme)
        applyTabBarAppearance(theme: theme, sepiaWarm: preferences.sepiaWarmTint)
        let bg = uiBackground(for: theme, sepiaWarm: preferences.sepiaWarmTint)
        let label: UIColor = (theme == .dark) ? .white : .black

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = bg
        nav.titleTextAttributes = [.foregroundColor: label]
        nav.largeTitleTextAttributes = [.foregroundColor: label]
        nav.shadowColor = .clear
        nav.shadowImage = UIImage()

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = nav
        navBar.scrollEdgeAppearance = nav
        navBar.compactAppearance = nav
        navBar.compactScrollEdgeAppearance = nav
        navBar.tintColor = label
        navBar.shadowImage = UIImage()

        UISearchBar.appearance().tintColor = label
        UISearchBar.appearance().barTintColor = bg

        // Do not customize UITextField inside UISearchBar (layout cost + past iOS crashes with UIAppearance).

        // Do not use UISearchTextField.appearance(...): setSpellCheckingType / backgroundColor etc.
        // crash on newer iOS when applied via UIAppearance (SwiftUI .searchable).

        // Plain SwiftUI `List` still shows default white behind section chrome unless the table view is tinted.
        UITableView.appearance().backgroundColor = rowUICol
        UITableView.appearance().separatorColor = UIColor.separator.withAlphaComponent(theme == .dark ? 0.35 : 0.25)

        // Grouped list cells: tint to match reading theme.
        let rowUICol = uiBackground(for: theme, sepiaWarm: preferences.sepiaWarmTint)
        var cellBg = UIBackgroundConfiguration.listGroupedCell()
        cellBg.backgroundColor = rowUICol
        UITableViewCell.appearance().backgroundConfiguration = cellBg

        // SwiftUI `List` section headers use UITableViewHeaderFooterView; `.clear()` lets the default white show
        // through. UIBackgroundConfiguration() is not public — start from `.clear()` then set the fill color.
        var headerFooterBg = UIBackgroundConfiguration.clear()
        headerFooterBg.backgroundColor = rowUICol
        UITableViewHeaderFooterView.appearance().backgroundConfiguration = headerFooterBg

        UICollectionView.appearance().backgroundColor = .clear
    }

    static func syncTabBar(with theme: ReadingPreferences.Theme) {
        applyTabBarAppearance(theme: theme, sepiaWarm: false)
    }

    private static func applyTabBarAppearance(theme: ReadingPreferences.Theme, sepiaWarm: Bool) {
        let bg = uiBackground(for: theme, sepiaWarm: sepiaWarm)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = bg
        let tab = UITabBar.appearance()
        tab.standardAppearance = appearance
        tab.scrollEdgeAppearance = appearance
    }

    private static func uiBackground(for theme: ReadingPreferences.Theme, sepiaWarm: Bool) -> UIColor {
        switch theme {
        case .light:
            return UIColor(red: 0.945, green: 0.968, blue: 0.995, alpha: 1)
        case .dark:
            return .black
        case .sepia:
            if sepiaWarm {
                return UIColor(red: 0.94, green: 0.90, blue: 0.78, alpha: 1)
            }
            return UIColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 1)
        }
    }
}
