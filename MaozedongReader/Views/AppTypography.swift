import SwiftUI
import UIKit

/// App-wide UI fonts using embedded Noto Serif CJK SC with system fallback.
enum AppTypography {
    static func uiFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        AppFonts.registerBundledFontsIfNeeded()
        let name = AppFonts.bundledPrintSerifPostScriptName
        if let base = UIFont(name: name, size: size) {
            return UIFont(descriptor: base.fontDescriptor.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: weight]
            ]), size: size)
        }
        return .systemFont(ofSize: size, weight: weight)
    }

    static func swiftUIFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        AppFonts.registerBundledFontsIfNeeded()
        let u = CGFloat(size)
        let w = weight
        if UIFont(name: AppFonts.bundledPrintSerifPostScriptName, size: u) != nil {
            return Font.custom(AppFonts.bundledPrintSerifPostScriptName, size: u).weight(w)
        }
        return Font.system(size: u, weight: w, design: .serif)
    }
}
