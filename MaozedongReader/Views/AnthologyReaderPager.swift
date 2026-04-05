import SwiftUI

struct AnthologyReaderPager: View {
    @EnvironmentObject private var store: DocumentStore

    private let ordered: [DocumentItem]
    @State private var selectionId: UUID

    init(allDocuments: [DocumentItem], initial: DocumentItem) {
        let key = initial.anthologyScrollGroupKey
        ordered = allDocuments
            .filter { $0.category == .anthology && $0.anthologyScrollGroupKey == key }
            .sorted(by: DocumentItem.displaySort)
        _selectionId = State(initialValue: initial.id)
    }

    private var currentTitle: String {
        ordered.first(where: { $0.id == selectionId })?.title ?? ""
    }

    var body: some View {
        Group {
            if ordered.count <= 1, let only = ordered.first {
                ReaderView(document: only, usesExternalNavigationTitle: false)
            } else {
                TabView(selection: $selectionId) {
                    ForEach(ordered) { doc in
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
        .onAppear {
            store.markDocumentOpened(documentId: selectionId)
        }
        .onChange(of: selectionId) { _, id in
            store.markDocumentOpened(documentId: id)
        }
    }
}
