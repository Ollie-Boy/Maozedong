import SwiftUI
import UIKit

/// Prefers 楷体 / 仿宋等印刷体，贴近年代书籍手写刻印风格；缺省回退衬线体。
enum ReaderTypography {
    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let u = CGFloat(size)
        let candidates = [
            "Kaiti SC", "STKaiti", "KaiTi_GB2312",
            "STFangsong", "STSong", "Songti SC"
        ]
        for name in candidates where UIFont(name: name, size: u) != nil {
            return Font.custom(name, size: u).weight(weight)
        }
        return Font.system(size: u, weight: weight, design: .serif)
    }

    static func boldFont(size: CGFloat) -> Font {
        bodyFont(size: size, weight: .semibold)
    }
}
