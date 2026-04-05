import SwiftUI

/// One article at a time: avoids `LazyHStack` of full `ReaderView`s (each holds a huge `content` string + parsed blocks),
/// which caused memory growth and freezes. Swipe horizontally to change the active document.
struct HorizontalReaderPager: View {
    let documents: [DocumentItem]
    @Binding var selectionId: UUID
    let orderedIds: [UUID]
    var onRequestPop: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let doc = resolvedDocument {
                ReaderView(document: doc)
                    .id(doc.id)
                    .contentShape(Rectangle())
                    .simultaneousGesture(horizontalPageSwipeGesture)
                    .onAppear {
                        if !orderedIds.contains(selectionId), let f = orderedIds.first {
                            selectionId = f
                        }
                    }
            } else {
                Color.clear
            }
        }
    }

    private var resolvedDocument: DocumentItem? {
        if let d = documents.first(where: { $0.id == selectionId }) { return d }
        guard let first = orderedIds.first else { return nil }
        return documents.first(where: { $0.id == first })
    }

    private var horizontalPageSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                let t = value.translation
                guard abs(t.width) > abs(t.height) * 1.12 else { return }
                guard let idx = orderedIds.firstIndex(of: selectionId) else { return }
                let lastIdx = orderedIds.count - 1

                if t.width > 60, idx > 0 {
                    selectionId = orderedIds[idx - 1]
                    return
                }
                if t.width < -60 {
                    if idx < lastIdx {
                        selectionId = orderedIds[idx + 1]
                    } else if value.startLocation.x > 160, t.width < -72 {
                        if let onRequestPop {
                            onRequestPop()
                        } else {
                            dismiss()
                        }
                    }
                }
            }
    }
}
