import SwiftUI

/// Horizontal paging with **at most three** `ReaderView` instances (previous / current / next).
/// Keeps the same swipe UX as a full `LazyHStack` but avoids dozens of huge markdown bodies in memory during layout.
struct HorizontalReaderPager: View {
    let documents: [DocumentItem]
    @Binding var selectionId: UUID
    let orderedIds: [UUID]
    var onRequestPop: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    private var windowedDocuments: [DocumentItem] {
        guard let idx = orderedIds.firstIndex(of: selectionId) else {
            return documents.filter { $0.id == selectionId }
        }
        let lo = max(0, idx - 1)
        let hi = min(orderedIds.count - 1, idx + 1)
        return (lo...hi).compactMap { j in
            let id = orderedIds[j]
            return documents.first { $0.id == id }
        }
    }

    private var scrollPositionBinding: Binding<UUID?> {
        Binding(
            get: { selectionId },
            set: { newId in
                if let newId { selectionId = newId }
            }
        )
    }

    var body: some View {
        let windowed = windowedDocuments
        Group {
            if windowed.isEmpty {
                Color.clear
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(windowed) { doc in
                            ReaderView(document: doc, presentsNavigationChrome: doc.id == selectionId)
                                .containerRelativeFrame(.horizontal)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: scrollPositionBinding)
                .modifier(PagerBoundaryPopModifier(orderedIds: orderedIds, selection: $selectionId, onPop: {
                    if let onRequestPop {
                        onRequestPop()
                    } else {
                        dismiss()
                    }
                }))
            }
        }
    }
}
