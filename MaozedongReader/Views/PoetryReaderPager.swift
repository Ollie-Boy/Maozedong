import SwiftUI

/// Horizontal paging between poetry items in chronological (display) order.
struct PoetryReaderPager: View {
    @EnvironmentObject private var store: DocumentStore

    private let orderedPoems: [DocumentItem]
    @State private var selectionId: UUID
    var onRequestPop: (() -> Void)?

    init(allDocuments: [DocumentItem], initial: DocumentItem, onRequestPop: (() -> Void)? = nil) {
        orderedPoems = allDocuments
            .filter { $0.category == .poetry }
            .sorted(by: DocumentItem.displaySort)
        _selectionId = State(initialValue: initial.id)
        self.onRequestPop = onRequestPop
    }

    private var ids: [UUID] {
        orderedPoems.map(\.id)
    }

    var body: some View {
        Group {
            if orderedPoems.count <= 1, let only = orderedPoems.first {
                ReaderView(document: only)
            } else {
                HorizontalReaderPager(
                    documents: orderedPoems,
                    selectionId: $selectionId,
                    orderedIds: ids,
                    onRequestPop: onRequestPop
                )
            }
        }
        .background(store.readingPreferences.backgroundColor.ignoresSafeArea())
        .toolbarBackground(store.readingPreferences.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(store.readingPreferences.backgroundColor, for: .bottomBar)
        .toolbarBackground(.visible, for: .bottomBar)
        .onChange(of: selectionId) { _, id in
            store.scheduleRecordLastOpenedDocument(documentId: id)
        }
        .onDisappear {
            store.flushLastOpenedDocumentSchedule()
        }
    }
}
