import SwiftUI

/// Horizontal paging between poetry items in chronological (display) order.
struct PoetryReaderPager: View {
    @EnvironmentObject private var store: DocumentStore

    private let orderedPoems: [DocumentItem]
    @State private var selectionId: UUID

    init(allDocuments: [DocumentItem], initial: DocumentItem) {
        orderedPoems = allDocuments
            .filter { $0.category == .poetry }
            .sorted(by: DocumentItem.displaySort)
        _selectionId = State(initialValue: initial.id)
    }

    private var currentTitle: String {
        orderedPoems.first(where: { $0.id == selectionId })?.title ?? ""
    }

    var body: some View {
        Group {
            if orderedPoems.count <= 1, let only = orderedPoems.first {
                ReaderView(document: only, usesExternalNavigationTitle: false)
            } else {
                TabView(selection: $selectionId) {
                    ForEach(orderedPoems) { doc in
                        ReaderView(document: doc, usesExternalNavigationTitle: true)
                            .tag(doc.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .background(store.readingPreferences.backgroundColor.ignoresSafeArea())
        .navigationTitle(currentTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(store.readingPreferences.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(store.readingPreferences.backgroundColor, for: .bottomBar)
        .toolbarBackground(.visible, for: .bottomBar)
    }
}
