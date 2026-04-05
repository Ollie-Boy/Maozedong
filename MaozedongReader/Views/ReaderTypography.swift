import SwiftUI
import UIKit

/// Body text uses embedded Noto Serif CJK SC (Song-style print); see `Resources/Fonts` + SIL license.
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
