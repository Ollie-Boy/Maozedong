import SwiftUI
import UIKit

/// Reader body fonts via embedded Noto Serif CJK SC.
enum ReaderTypography {
    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        AppTypography.swiftUIFont(size: size, weight: weight)
    }

    static func boldFont(size: CGFloat) -> Font {
        bodyFont(size: size, weight: .semibold)
    }

    static func uiFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        AppTypography.uiFont(size: size, weight: weight)
    }
}
