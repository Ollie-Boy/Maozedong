import SwiftUI

struct AnthologyReaderPager: View {
    @EnvironmentObject private var store: DocumentStore

    private let ordered: [DocumentItem]
    @State private var selectionId: UUID

    init(allDocuments: [DocumentItem], initial: DocumentItem) {
        ordered = allDocuments
            .filter { $0.category == .anthology }
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
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
        .navigationTitle(currentTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
