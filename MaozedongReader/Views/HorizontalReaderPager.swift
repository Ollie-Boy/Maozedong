import SwiftUI

/// Lazy horizontal paging: only the selected `ReaderView` registers navigation chrome (toolbar/title),
/// avoiding stacked `TabView` pages fighting the navigation bar during transitions.
struct HorizontalReaderPager: View {
    let documents: [DocumentItem]
    @Binding var selectionId: UUID
    let orderedIds: [UUID]
    var onRequestPop: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

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
                .scrollPosition(
                    id: Binding(
                        get: { selectionId },
                        set: { newId in
                            if let newId { selectionId = newId }
                        }
                    )
                )
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
