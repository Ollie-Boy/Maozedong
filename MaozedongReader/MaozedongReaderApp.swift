import SwiftUI

@main
struct MaozedongReaderApp: App {
    @StateObject private var store = DocumentStore()
    @Environment(\.colorScheme) private var colorScheme
    @State private var navPath = NavigationPath()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navPath) {
                LibraryView(path: $navPath)
            }
            .environmentObject(store)
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
