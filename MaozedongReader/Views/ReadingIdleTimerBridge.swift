import SwiftUI

/// Keeps the device awake while the reader navigation stack is non-empty (one push/pop pair).
struct ReadingIdleTimerBridge: View {
    @Binding var path: NavigationPath
    @State private var readingStackActive = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                sync(pathEmpty: path.isEmpty)
            }
            .onChange(of: path.isEmpty) { _, isEmpty in
                sync(pathEmpty: isEmpty)
            }
            .onDisappear {
                if readingStackActive {
                    IdleTimerController.popReadingSession()
                    readingStackActive = false
                }
            }
    }

    private func sync(pathEmpty: Bool) {
        let should = !pathEmpty
        if should == readingStackActive { return }
        if should {
            IdleTimerController.pushReadingSession()
        } else {
            IdleTimerController.popReadingSession()
        }
        readingStackActive = should
    }
}
