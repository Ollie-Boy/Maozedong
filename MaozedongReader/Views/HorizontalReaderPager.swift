import SwiftUI

/// Three-column strip with **finger-driven horizontal offset** (ebook-style): drag shows the next/prev page moving in;
/// release completes past ~20% width, a distance threshold, or a quick flick; otherwise eases back to center.
struct HorizontalReaderPager: View {
    let documents: [DocumentItem]
    @Binding var selectionId: UUID
    let orderedIds: [UUID]
    var onRequestPop: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var reelSlots: [UUID?] = [nil, nil, nil]
    /// Added to resting offset `-pageWidth` so the strip follows the finger during a horizontal drag.
    @State private var dragTranslation: CGFloat = 0
    @State private var horizontalDragActive = false
    @State private var dragStartX: CGFloat = 0

    private func document(for id: UUID?) -> DocumentItem? {
        guard let id else { return nil }
        return documents.first { $0.id == id }
    }

    private func syncReelToSelection() {
        guard let idx = orderedIds.firstIndex(of: selectionId) else { return }
        let n = orderedIds.count
        reelSlots = [
            idx > 0 ? orderedIds[idx - 1] : nil,
            orderedIds[idx],
            idx < n - 1 ? orderedIds[idx + 1] : nil
        ]
    }

    private func commitToPreviousPage() {
        guard let centerIdx = orderedIds.firstIndex(of: selectionId), centerIdx > 0 else { return }
        let newIdx = centerIdx - 1
        selectionId = orderedIds[newIdx]
        let n = orderedIds.count
        reelSlots = [
            newIdx > 0 ? orderedIds[newIdx - 1] : nil,
            orderedIds[newIdx],
            newIdx < n - 1 ? orderedIds[newIdx + 1] : nil
        ]
    }

    private func commitToNextPage() {
        guard let centerIdx = orderedIds.firstIndex(of: selectionId), centerIdx < orderedIds.count - 1 else { return }
        let newIdx = centerIdx + 1
        selectionId = orderedIds[newIdx]
        let n = orderedIds.count
        reelSlots = [
            newIdx > 0 ? orderedIds[newIdx - 1] : nil,
            orderedIds[newIdx],
            newIdx < n - 1 ? orderedIds[newIdx + 1] : nil
        ]
    }

    @ViewBuilder
    private func slotView(slot: Int, width: CGFloat) -> some View {
        Group {
            if let doc = document(for: reelSlots[slot]) {
                ReaderView(document: doc, presentsNavigationChrome: slot == 1)
                    .id(doc.id)
            } else {
                Color.clear
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
    }

    var body: some View {
        Group {
            if documents.isEmpty {
                Color.clear
            } else {
                GeometryReader { geo in
                    let W = max(geo.size.width, 1)
                    let H = geo.size.height
                    let idx = orderedIds.firstIndex(of: selectionId)
                    let hasPrev = (idx ?? 0) > 0
                    let hasNext = idx.map { $0 < orderedIds.count - 1 } ?? false
                    let restingOffset = -W
                    let rawOffset = restingOffset + dragTranslation
                    let minOffset = hasNext ? -2 * W : -W
                    let maxOffset = hasPrev ? 0 : -W
                    let clampedOffset = min(max(rawOffset, minOffset), maxOffset)
                    let progress = (clampedOffset + W) / W

                    HStack(spacing: 0) {
                        slotView(slot: 0, width: W)
                        slotView(slot: 1, width: W)
                        slotView(slot: 2, width: W)
                    }
                    .frame(width: 3 * W, alignment: .leading)
                    .offset(x: clampedOffset)
                    .frame(width: W, height: H, alignment: .leading)
                    .clipped()
                    .contentShape(Rectangle())
                    // Run alongside inner vertical ScrollView: only after we lock horizontal does translation drive the strip.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onChanged { value in
                                let t = value.translation
                                if !horizontalDragActive {
                                    if hypot(t.width, t.height) < 12 { return }
                                    if abs(t.width) < abs(t.height) * 1.12 { return }
                                    horizontalDragActive = true
                                    dragStartX = value.startLocation.x
                                }
                                guard horizontalDragActive else { return }
                                dragTranslation = t.width
                            }
                            .onEnded { value in
                                defer {
                                    horizontalDragActive = false
                                }
                                guard horizontalDragActive else {
                                    dragTranslation = 0
                                    return
                                }

                                let t = value.translation.width
                                let flickExtra = value.predictedEndTranslation.width - t

                                let goNext = hasNext && (progress < -0.2 || t < -56 || flickExtra < -100)
                                let goPrev = hasPrev && (progress > 0.2 || t > 56 || flickExtra > 100)

                                if goNext && !goPrev {
                                    withAnimation(.easeOut(duration: 0.28)) {
                                        dragTranslation = -W
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.29) {
                                        commitToNextPage()
                                        var tr = Transaction()
                                        tr.disablesAnimations = true
                                        withTransaction(tr) {
                                            dragTranslation = 0
                                        }
                                    }
                                } else if goPrev && !goNext {
                                    withAnimation(.easeOut(duration: 0.28)) {
                                        dragTranslation = W
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.29) {
                                        commitToPreviousPage()
                                        var tr = Transaction()
                                        tr.disablesAnimations = true
                                        withTransaction(tr) {
                                            dragTranslation = 0
                                        }
                                    }
                                } else {
                                    withAnimation(.easeOut(duration: 0.22)) {
                                        dragTranslation = 0
                                    }
                                    let isLast = orderedIds.last == selectionId
                                    if isLast, !hasNext, dragStartX > W * 0.42, t < -64 {
                                        if let onRequestPop {
                                            onRequestPop()
                                        } else {
                                            dismiss()
                                        }
                                    }
                                }
                            }
                    )
                }
            }
        }
        .onAppear {
            syncReelToSelection()
        }
        .onChange(of: selectionId) { _, _ in
            syncReelToSelection()
            var tr = Transaction()
            tr.disablesAnimations = true
            withTransaction(tr) {
                dragTranslation = 0
            }
        }
    }
}
