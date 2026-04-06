import SwiftUI

struct ReadingPreferences: Codable, Equatable {
    var fontSize: Double
    var lineSpacing: Double
    /// Extra vertical gap between Markdown blocks (headings, paragraphs, lists).
    var readerBlockSpacing: Double
    /// Horizontal inset for reading column (pt).
    var readerHorizontalPadding: Double
    /// 0 = full width; otherwise max content width for long lines (pt), centered on iPad/wide phones.
    var readerMaxColumnWidth: Double
    var theme: Theme
    /// 护眼偏暖（略深、略黄），仅在选择「护眼」时生效。
    var sepiaWarmTint: Bool
    /// 22:00–07:00 自动使用深色（需未勾选跟随系统）。
    var autoDarkAtNight: Bool
    /// 使用系统浅色/深色，忽略下方手动主题（护眼仍为手动）。
    var followSystemAppearance: Bool

    init(
        fontSize: Double = 18,
        lineSpacing: Double = 7,
        readerBlockSpacing: Double = 14,
        readerHorizontalPadding: Double = 20,
        readerMaxColumnWidth: Double = 0,
        theme: Theme = .sepia,
        sepiaWarmTint: Bool = false,
        autoDarkAtNight: Bool = false,
        followSystemAppearance: Bool = false
    ) {
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.readerBlockSpacing = readerBlockSpacing
        self.readerHorizontalPadding = readerHorizontalPadding
        self.readerMaxColumnWidth = readerMaxColumnWidth
        self.theme = theme
        self.sepiaWarmTint = sepiaWarmTint
        self.autoDarkAtNight = autoDarkAtNight
        self.followSystemAppearance = followSystemAppearance
    }

    enum Theme: String, CaseIterable, Codable, Identifiable {
        case light
        case dark
        case sepia

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .light:
                return "浅色"
            case .dark:
                return "深色"
            case .sepia:
                return "护眼"
            }
        }

        var backgroundColor: Color {
            switch self {
            case .light:
                return Color.white
            case .dark:
                return Color.black
            case .sepia:
                return Color(red: 0.96, green: 0.93, blue: 0.86)
            }
        }

        func backgroundColor(sepiaWarm: Bool) -> Color {
            guard self == .sepia, sepiaWarm else { return backgroundColor }
            return Color(red: 0.94, green: 0.90, blue: 0.78)
        }

        var textColor: Color {
            switch self {
            case .light, .sepia:
                return Color.black
            case .dark:
                return Color.white
            }
        }
    }

    var backgroundColor: Color {
        theme.backgroundColor(sepiaWarm: sepiaWarmTint)
    }

    var textColor: Color {
        theme.textColor
    }

    var secondaryTextColor: Color {
        switch theme {
        case .light, .sepia:
            return Color(white: 0.45)
        case .dark:
            return Color(white: 0.65)
        }
    }

    var accentQuoteColor: Color {
        switch theme {
        case .light:
            return Color(red: 0.2, green: 0.45, blue: 0.75)
        case .dark:
            return Color(red: 0.45, green: 0.7, blue: 1.0)
        case .sepia:
            return Color(red: 0.55, green: 0.35, blue: 0.15)
        }
    }
}

extension ReadingPreferences {
    static let `default` = ReadingPreferences()

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 18
        lineSpacing = try c.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? 7
        readerBlockSpacing = try c.decodeIfPresent(Double.self, forKey: .readerBlockSpacing) ?? 14
        readerHorizontalPadding = try c.decodeIfPresent(Double.self, forKey: .readerHorizontalPadding) ?? 20
        readerMaxColumnWidth = try c.decodeIfPresent(Double.self, forKey: .readerMaxColumnWidth) ?? 0
        theme = try c.decodeIfPresent(Theme.self, forKey: .theme) ?? .sepia
        sepiaWarmTint = try c.decodeIfPresent(Bool.self, forKey: .sepiaWarmTint) ?? false
        autoDarkAtNight = try c.decodeIfPresent(Bool.self, forKey: .autoDarkAtNight) ?? false
        followSystemAppearance = try c.decodeIfPresent(Bool.self, forKey: .followSystemAppearance) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fontSize, forKey: .fontSize)
        try c.encode(lineSpacing, forKey: .lineSpacing)
        try c.encode(readerBlockSpacing, forKey: .readerBlockSpacing)
        try c.encode(readerHorizontalPadding, forKey: .readerHorizontalPadding)
        try c.encode(readerMaxColumnWidth, forKey: .readerMaxColumnWidth)
        try c.encode(theme, forKey: .theme)
        try c.encode(sepiaWarmTint, forKey: .sepiaWarmTint)
        try c.encode(autoDarkAtNight, forKey: .autoDarkAtNight)
        try c.encode(followSystemAppearance, forKey: .followSystemAppearance)
    }

    private enum CodingKeys: String, CodingKey {
        case fontSize, lineSpacing, readerBlockSpacing, readerHorizontalPadding, readerMaxColumnWidth
        case theme, sepiaWarmTint, autoDarkAtNight, followSystemAppearance
    }
}
