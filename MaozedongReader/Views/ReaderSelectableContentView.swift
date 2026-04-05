import SwiftUI
import UIKit

/// Read-only `UITextView` for accurate UTF-16 selection mapping to `DocumentItem.content`.
struct ReaderSelectableContentView: UIViewRepresentable {
    let fullText: String
    let textColor: UIColor
    let font: UIFont
    @Binding var selection: NSRange

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 12, right: 12)
        tv.delegate = context.coordinator
        tv.text = fullText
        tv.textColor = textColor
        tv.font = font
        tv.adjustsFontForContentSizeCategory = true
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != fullText {
            uiView.text = fullText
        }
        uiView.textColor = textColor
        uiView.font = font
        if uiView.selectedRange != selection {
            let maxLen = (fullText as NSString).length
            var r = selection
            if r.location < 0 { r.location = 0 }
            if r.length < 0 { r.length = 0 }
            if r.location > maxLen { r.location = maxLen }
            if r.location + r.length > maxLen { r.length = maxLen - r.location }
            uiView.selectedRange = r
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ReaderSelectableContentView

        init(_ parent: ReaderSelectableContentView) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selection = textView.selectedRange
        }
    }
}
