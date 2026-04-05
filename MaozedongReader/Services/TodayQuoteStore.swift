import Foundation

/// Optional App Group (`group.com.example.MaozedongReader`) for widget; falls back to no-op if unset.
enum TodayQuoteStore {
    static let appGroupId = "group.com.example.MaozedongReader"
    private static let titleKey = "widgetTodayQuoteTitle"
    private static let lineKey = "widgetTodayQuoteLine"
    private static let dayKey = "widgetTodayQuoteDayOrdinal"

    private static var suite: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    /// Falls back to `standard` so the widget can read without App Group entitlements.
    private static var storage: UserDefaults {
        suite ?? .standard
    }

    static func refreshIfNeeded(from documents: [DocumentItem]) {
        let defaults = storage
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: Date())
        let dayOrdinal = (comps.year ?? 0) * 400 + (comps.month ?? 0) * 40 + (comps.day ?? 0)
        if defaults.integer(forKey: dayKey) == dayOrdinal,
           (defaults.string(forKey: lineKey) ?? "").isEmpty == false {
            return
        }
        let poems = documents.filter { $0.category == .poetry }.sorted(by: DocumentItem.displaySort)
        guard !poems.isEmpty else { return }
        let idx = abs(dayOrdinal) % poems.count
        let doc = poems[idx]
        let line = firstPoetryVerseLine(from: doc.content) ?? doc.title
        defaults.set(doc.title, forKey: titleKey)
        defaults.set(line, forKey: lineKey)
        defaults.set(dayOrdinal, forKey: dayKey)
    }

    static func snapshotForWidget() -> (title: String, line: String) {
        let defaults = storage
        let t = defaults.string(forKey: titleKey) ?? ""
        let l = defaults.string(forKey: lineKey) ?? ""
        if t.isEmpty && l.isEmpty { return ("今日一句", "打开主应用后自动更新") }
        return (t, l.isEmpty ? t : l)
    }

    private static func firstPoetryVerseLine(from markdown: String) -> String? {
        let lines = markdown.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        var afterHr = false
        for line in lines {
            if line == "---" { afterHr = true; continue }
            if line.hasPrefix("#") { continue }
            if line.hasPrefix("**"), line.hasSuffix("**"), line.count < 45 { continue }
            if line.isEmpty { continue }
            if line.contains("注释") { break }
            if afterHr { return String(line.prefix(100)) }
            if line.contains("，") || line.contains("。") {
                return String(line.prefix(100))
            }
        }
        return nil
    }
}
