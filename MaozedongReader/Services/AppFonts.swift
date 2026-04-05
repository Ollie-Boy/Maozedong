import CoreGraphics
import CoreText
import Foundation
import UIKit

/// Registers bundled print-style Song serif (Noto Serif CJK SC) for `ReaderTypography` / `AppTypography`.
enum AppFonts {
    /// PostScript name inside `NotoSerifCJKsc-Regular.otf` (SIL Open Font License 1.1).
    static let bundledPrintSerifPostScriptName = "NotoSerifCJKsc-Regular"

    private static let didRegisterLock = NSLock()
    private static var didRegister = false

    static func registerBundledFontsIfNeeded() {
        didRegisterLock.lock()
        defer { didRegisterLock.unlock() }
        guard !didRegister else { return }
        didRegister = true

        let names = [
            "NotoSerifCJKsc-Regular",
            "NotoSerifCJKsc-Regular.otf"
        ]
        for base in names {
            if let url = Bundle.main.url(forResource: base, withExtension: nil, subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: base.replacingOccurrences(of: ".otf", with: ""), withExtension: "otf", subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: base.replacingOccurrences(of: ".otf", with: ""), withExtension: "otf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
