import SwiftUI
import UIKit

/// Global UIKit chrome so navigation, search bars, and TabView footers match the reading theme.
enum AppAppearanceUIKit {
    static func syncGlobalChrome(theme: ReadingPreferences.Theme) {
        syncTabBar(theme: theme)
        let bg = uiBackground(for: theme)
        let label: UIColor = (theme == .dark) ? .white : .black

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = bg
        nav.titleTextAttributes = [.foregroundColor: label]
        nav.largeTitleTextAttributes = [.foregroundColor: label]

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = nav
        navBar.scrollEdgeAppearance = nav
        navBar.compactAppearance = nav
        navBar.compactScrollEdgeAppearance = nav
        navBar.tintColor = label

        UISearchBar.appearance().tintColor = label
        UISearchBar.appearance().barTintColor = bg

        // Do not use UISearchTextField.appearance(...): setSpellCheckingType / backgroundColor etc.
        // crash on newer iOS when applied via UIAppearance (SwiftUI .searchable).

        UITableView.appearance().backgroundColor = .clear
        UITableView.appearance().separatorColor = UIColor.separator.withAlphaComponent(theme == .dark ? 0.35 : 0.25)

        // Grouped list cells: tint to match reading theme.
        let rowUICol = uiBackground(for: theme)
        var cellBg = UIBackgroundConfiguration.listGroupedCell()
        cellBg.backgroundColor = rowUICol
        UITableViewCell.appearance().backgroundConfiguration = cellBg

        let clearHeaderFooter = UIBackgroundConfiguration.clear()
        UITableViewHeaderFooterView.appearance().backgroundConfiguration = clearHeaderFooter

        UICollectionView.appearance().backgroundColor = .clear
    }

    static func syncTabBar(with theme: ReadingPreferences.Theme) {
        syncTabBar(theme: theme)
    }

    private static func syncTabBar(theme: ReadingPreferences.Theme) {
        let bg = uiBackground(for: theme)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = bg
        let tab = UITabBar.appearance()
        tab.standardAppearance = appearance
        tab.scrollEdgeAppearance = appearance
    }

    private static func uiBackground(for theme: ReadingPreferences.Theme) -> UIColor {
        switch theme {
        case .light:
            return .systemBackground
        case .dark:
            return .black
        case .sepia:
            return UIColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 1)
        }
    }
}
