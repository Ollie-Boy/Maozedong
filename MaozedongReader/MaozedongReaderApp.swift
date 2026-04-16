import SwiftUI
import UIKit

@main
struct MaozedongReaderApp: App {
    @StateObject private var store = DocumentStore()
    @Environment(\.colorScheme) private var colorScheme
    @State private var navPath = NavigationPath()

    init() {
        AppFonts.registerBundledFontsIfNeeded()
        // Avoid global UIAppearance fonts on labels/text fields: bundled serif on every UILabel caused jank.
        // Reader uses embedded font via ReaderTypography; root `.font` covers most SwiftUI chrome.
        let semibold = AppTypography.uiFont(size: 17, weight: .semibold)
        UINavigationBar.appearance().titleTextAttributes = [.font: semibold]
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: AppTypography.uiFont(size: 34, weight: .bold)]
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navPath) {
                LibraryView(path: $navPath)
            }
            .environmentObject(store)
            .font(AppTypography.swiftUIFont(size: 17))
            .preferredColorScheme(store.readingPreferences.preferredColorSchemeResolved(environmentScheme: colorScheme))
            .onAppear {
                AppAppearanceUIKit.syncGlobalChrome(preferences: store.readingPreferences, environmentScheme: colorScheme)
            }
            .onChange(of: store.readingPreferences.theme) { _, _ in
                AppAppearanceUIKit.syncGlobalChrome(preferences: store.readingPreferences, environmentScheme: colorScheme)
            }
            .onChange(of: store.readingPreferences.sepiaWarmTint) { _, _ in
                AppAppearanceUIKit.syncGlobalChrome(preferences: store.readingPreferences, environmentScheme: colorScheme)
            }
            .onChange(of: store.readingPreferences.followSystemAppearance) { _, _ in
                AppAppearanceUIKit.syncGlobalChrome(preferences: store.readingPreferences, environmentScheme: colorScheme)
            }
            .onChange(of: store.readingPreferences.autoDarkAtNight) { _, _ in
                AppAppearanceUIKit.syncGlobalChrome(preferences: store.readingPreferences, environmentScheme: colorScheme)
            }
            .onChange(of: colorScheme) { _, _ in
                AppAppearanceUIKit.syncGlobalChrome(preferences: store.readingPreferences, environmentScheme: colorScheme)
            }
            .onReceive(Timer.publish(every: 600, on: .main, in: .common).autoconnect()) { _ in
                if store.readingPreferences.autoDarkAtNight {
                    AppAppearanceUIKit.syncGlobalChrome(preferences: store.readingPreferences, environmentScheme: colorScheme)
                }
            }
        }
    }
}
