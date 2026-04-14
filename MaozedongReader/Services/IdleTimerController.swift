import UIKit

/// Central place to toggle `UIApplication.isIdleTimerDisabled` while reading or during speech playback.
@MainActor
enum IdleTimerController {
    private static var readingDepth = 0
    private static var speechActive = false

    static func pushReadingSession() {
        readingDepth += 1
        sync()
    }

    static func popReadingSession() {
        readingDepth = max(0, readingDepth - 1)
        sync()
    }

    static func setSpeechPlaybackActive(_ active: Bool) {
        speechActive = active
        sync()
    }

    private static func sync() {
        let disable = readingDepth > 0 || speechActive
        UIApplication.shared.isIdleTimerDisabled = disable
    }
}
