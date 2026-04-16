import UIKit

/// Central place to toggle `UIApplication.isIdleTimerDisabled` while reading or during speech playback.
@MainActor
enum IdleTimerController {
    /// True while the root `NavigationStack` has pushed a reader route (library is not the only screen).
    private static var readingRouteActive = false
    private static var speechActive = false

    static func setReadingRouteActive(_ active: Bool) {
        readingRouteActive = active
        sync()
    }

    static func setSpeechPlaybackActive(_ active: Bool) {
        speechActive = active
        sync()
    }

    private static func sync() {
        let disable = readingRouteActive || speechActive
        UIApplication.shared.isIdleTimerDisabled = disable
    }
}
