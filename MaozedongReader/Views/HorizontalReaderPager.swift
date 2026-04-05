import SwiftUI

/// Full `LazyHStack` of articles so `scrollPosition(id:)` IDs stay stable. A sliding **3-page window** caused
/// the HStack’s children to be replaced on every selection change; scroll offset and id binding disagreed and
/// one light flick could snap through many pages.
struct HorizontalReaderPager: View {
    let documents: [DocumentItem]
    @Binding var selectionId: UUID
    let orderedIds: [UUID]
    var onRequestPop: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    private var scrollPositionBinding: Binding<UUID?> {
        Binding(
            get: { selectionId },
            set: { newId in
                if let newId { selectionId = newId }
            }
        )
    }

    var body: some View {
        Group {
            if documents.isEmpty {
                Color.clear
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(documents) { doc in
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
