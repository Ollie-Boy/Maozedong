import SwiftUI

/// Three fixed slots `[prev?, current, next?]` so `scrollPosition` ids stay `0,1,2` while only **three**
/// `ReaderView`s exist. After a real page change, the reel updates and the scroll eases back to center with a
/// spring (e.g. book-like settle); first/last edge bounce still snaps instantly.
struct HorizontalReaderPager: View {
    let documents: [DocumentItem]
    @Binding var selectionId: UUID
    let orderedIds: [UUID]
    var onRequestPop: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var reelSlots: [UUID?] = [nil, nil, nil]
    @State private var focusedSlot: Int = 1

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

    private func commitReelNavigation(from slot: Int) {
        guard let centerIdx = orderedIds.firstIndex(of: selectionId) else { return }
        var newIdx = centerIdx
        if slot == 0 {
            guard centerIdx > 0 else {
                snapToCenterWithoutAnimation()
                return
            }
            newIdx = centerIdx - 1
        } else if slot == 2 {
            guard centerIdx < orderedIds.count - 1 else {
                snapToCenterWithoutAnimation()
                return
            }
            newIdx = centerIdx + 1
        } else {
            return
        }

        selectionId = orderedIds[newIdx]
        let n = orderedIds.count
        reelSlots = [
            newIdx > 0 ? orderedIds[newIdx - 1] : nil,
            orderedIds[newIdx],
            newIdx < n - 1 ? orderedIds[newIdx + 1] : nil
        ]
        snapToCenterWithPageTurnAnimation()
    }

    /// Instant reset when bouncing at first/last article (no “fake” page turn).
    private func snapToCenterWithoutAnimation() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            focusedSlot = 1
        }
    }

    /// After a real page change, ease back to the middle slot like turning a page (was instant before).
    private func snapToCenterWithPageTurnAnimation() {
        withAnimation(.spring(response: 0.52, dampingFraction: 0.86, blendDuration: 0.2)) {
            focusedSlot = 1
        }
    }

    var body: some View {
        Group {
            if documents.isEmpty {
                Color.clear
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(0 ..< 3, id: \.self) { slot in
                            Group {
                                if let doc = document(for: reelSlots[slot]) {
                                    ReaderView(document: doc, presentsNavigationChrome: slot == 1)
                                        .id(doc.id)
                                } else {
                                    Color.clear
                                }
                            }
                            .containerRelativeFrame(.horizontal)
                            .id(slot)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollBounceBehavior(.basedOnSize)
                .scrollPosition(id: Binding(
                    get: { focusedSlot },
                    set: { if let s = $0 { focusedSlot = s } }
                ))
                .onAppear {
                    syncReelToSelection()
                    focusedSlot = 1
                }
                .onChange(of: selectionId) { _, _ in
                    syncReelToSelection()
                    snapToCenterWithoutAnimation()
                }
                .onChange(of: focusedSlot) { _, newSlot in
                    guard newSlot != 1 else { return }
                    commitReelNavigation(from: newSlot)
                }
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
