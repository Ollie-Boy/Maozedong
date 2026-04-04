import SwiftUI

@main
struct MaozedongReaderApp: App {
    @StateObject private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(store)
        }
    }
}
