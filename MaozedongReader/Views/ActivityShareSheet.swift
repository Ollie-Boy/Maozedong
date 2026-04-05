import SwiftUI
import UIKit

/// Presents the system share sheet for saving or AirDropping files (avoids `fileExporter` API drift across SDKs).
struct ActivityShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
