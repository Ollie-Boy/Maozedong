import SwiftUI

@main
struct MaozedongReaderApp: App {
    @StateObject private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                LibraryView()
            }
            .environmentObject(store)
            .preferredColorScheme(store.readingPreferences.theme.preferredColorScheme)
            .onAppear {
                AppAppearanceUIKit.syncGlobalChrome(theme: store.readingPreferences.theme)
            }
            .onChange(of: store.readingPreferences.theme) { _, theme in
                AppAppearanceUIKit.syncGlobalChrome(theme: theme)
            }
            .onChange(of: store.readingPreferences) { _, prefs in
                AppAppearanceUIKit.syncGlobalChrome(theme: prefs.theme)
            }
        }
    }
}
