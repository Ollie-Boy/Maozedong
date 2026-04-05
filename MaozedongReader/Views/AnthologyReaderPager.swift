import SwiftUI

/// Horizontal paging between anthology items in the same **library display order** as poetry:
/// all 选集篇目可左右滑动切换（不再限制在同一卷内 `##` 分组）。
struct AnthologyReaderPager: View {
    @EnvironmentObject private var store: DocumentStore

    private let ordered: [DocumentItem]
    @State private var selectionId: UUID
    var onRequestPop: (() -> Void)?

    init(allDocuments: [DocumentItem], initial: DocumentItem, onRequestPop: (() -> Void)? = nil) {
        ordered = allDocuments
            .filter { $0.category == .anthology }
            .sorted(by: DocumentItem.displaySort)
        _selectionId = State(initialValue: initial.id)
        self.onRequestPop = onRequestPop
    }

    private var ids: [UUID] {
        ordered.map(\.id)
    }

    var body: some View {
        Group {
            if ordered.count <= 1, let only = ordered.first {
                ReaderView(document: only)
            } else {
                HorizontalReaderPager(
                    documents: ordered,
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
