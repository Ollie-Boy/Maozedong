import SwiftUI

@main
struct MaozedongReaderApp: App {
    @StateObject private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(store)
                .preferredColorScheme(store.readingPreferences.theme.preferredColorScheme)
                .onAppear {
                    AppAppearanceUIKit.syncTabBar(with: store.readingPreferences.theme)
                }
                .onChange(of: store.readingPreferences.theme) { _, theme in
                    AppAppearanceUIKit.syncTabBar(with: theme)
                }
        }
    }
}
