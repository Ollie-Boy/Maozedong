import SwiftUI
import UIKit

/// Prefers 仿宋 / 宋体 on iOS; falls back to serif system font.
enum ReaderTypography {
    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let u = CGFloat(size)
        if UIFont(name: "STFangsong", size: u) != nil {
            return Font.custom("STFangsong", size: u).weight(weight)
        }
        if UIFont(name: "STSong", size: u) != nil {
            return Font.custom("STSong", size: u).weight(weight)
        }
        if UIFont(name: "Songti SC", size: u) != nil {
            return Font.custom("Songti SC", size: u).weight(weight)
        }
        return Font.system(size: u, weight: weight, design: .serif)
    }

    static func boldFont(size: CGFloat) -> Font {
        bodyFont(size: size, weight: .semibold)
    }
}
