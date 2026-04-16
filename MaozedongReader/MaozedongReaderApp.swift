import SwiftUI
import UIKit

@main
struct MaozedongReaderApp: App {
    @StateObject private var store = DocumentStore()
    @StateObject private var speechSession = SpeechSessionController()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var navPath = NavigationPath()

    init() {
        AppFonts.registerBundledFontsIfNeeded()
        // Do not set UILabel / UITextField / UITextView / UIButton UIAppearance fonts: SwiftUI Text is backed by
        // UILabels, and forcing every label to use the bundled CJK serif caused severe jank and climbing memory
        // after commit 425056d. Reader text still uses the embedded font via ReaderTypography / AttributedString;
        // the root SwiftUI `.font` below covers most on-screen UI without touching every system label.
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
            .environmentObject(speechSession)
            .font(AppTypography.swiftUIFont(size: 17))
            .preferredColorScheme(store.readingPreferences.preferredColorSchemeResolved(environmentScheme: colorScheme))
            .onAppear {
                IdleTimerController.setReadingRouteActive(!navPath.isEmpty)
                AppAppearanceUIKit.syncGlobalChrome(preferences: store.readingPreferences, environmentScheme: colorScheme)
            }
            .onChange(of: navPath.count) { _, _ in
                let inReader = !navPath.isEmpty
                IdleTimerController.setReadingRouteActive(inReader)
                if !inReader {
                    speechSession.stop()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    IdleTimerController.reapplyIdleTimerState()
                }
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
