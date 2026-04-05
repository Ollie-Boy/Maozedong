import SwiftUI

/// When `selection` is the last id in `orderedIds`, a leftward drag from the right half pops navigation.
struct PagerBoundaryPopModifier: ViewModifier {
    let orderedIds: [UUID]
    @Binding var selection: UUID
    var onPop: () -> Void

    @State private var dragStartX: CGFloat?

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 24, coordinateSpace: .local)
                    .onChanged { v in
                        if dragStartX == nil { dragStartX = v.startLocation.x }
                    }
                    .onEnded { v in
                        defer { dragStartX = nil }
                        guard let startX = dragStartX else { return }
                        guard let last = orderedIds.last, selection == last else { return }
                        // Started from right half and swiped left (trying to go past last page).
                        if startX > 160, v.translation.width < -70 {
                            onPop()
                        }
                    }
            )
    }
}
