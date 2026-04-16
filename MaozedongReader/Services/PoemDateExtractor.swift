import Foundation

/// Sortable (year, month, day) from the first lines of poem body after the title line.
enum PoemDateExtractor {
    private static let lunarMonthNames: [String: Int] = [
        "正月": 1, "二月": 2, "三月": 3, "四月": 4, "五月": 5, "六月": 6,
        "七月": 7, "八月": 8, "九月": 9, "十月": 10, "冬月": 11, "十一月": 11,
        "腊月": 12, "十二月": 12, "元月": 1
    ]

    static func components(from body: String) -> (year: Int?, month: Int?, day: Int?) {
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(6)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .map { stripMarkdownBoldEdges($0) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return (nil, nil, nil) }

        let head = lines.prefix(4).joined(separator: " ")

        if let y = yearRangeLowerBound(in: head) {
            let m = explicitMonth(in: head) ?? seasonMonth(in: head) ?? lunarMonth(in: head)
            let d = explicitDay(in: head)
            return (y, m, d)
        }

        if let y = firstFourDigitYear(in: head) {
            return (y, seasonMonth(in: head) ?? lunarMonth(in: head), explicitDay(in: head))
        }

        // Year without 年 suffix, or bare four-digit year on first meta line.
        if let firstLine = lines.first,
           let y = fourDigitYearWithoutRequiredNian(in: firstLine) {
            let m = explicitMonth(in: head) ?? seasonMonth(in: head) ?? lunarMonth(in: head)
            let d = explicitDay(in: head)
            return (y, m, d)
        }

        return (nil, nil, nil)
    }

    private static func stripMarkdownBoldEdges(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        while t.hasPrefix("**"), t.hasSuffix("**"), t.count >= 4 {
            t = String(t.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
        }
        return t
    }

    private static func yearRangeLowerBound(in s: String) -> Int? {
        let p = try? NSRegularExpression(pattern: "(\\d{4})\\s*年\\s*至\\s*\\d{4}\\s*年", options: [])
        let ns = s as NSString
        guard let m = p?.firstMatch(in: s, options: [], range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: s),
              let y = Int(s[r]) else { return nil }
        return y
    }

    private static func explicitMonth(in s: String) -> Int? {
        let p = try? NSRegularExpression(pattern: "(\\d{4})\\s*年\\s*(\\d{1,2})\\s*月", options: [])
        let ns = s as NSString
        guard let m = p?.firstMatch(in: s, options: [], range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 3,
              let r = Range(m.range(at: 2), in: s),
              let mo = Int(s[r]), (1 ... 12).contains(mo) else { return nil }
        return mo
    }

    private static func explicitDay(in s: String) -> Int? {
        let p = try? NSRegularExpression(pattern: "年\\s*(\\d{1,2})\\s*月\\s*(\\d{1,2})\\s*日", options: [])
        let ns = s as NSString
        guard let m = p?.firstMatch(in: s, options: [], range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 3,
              let r = Range(m.range(at: 2), in: s),
              let d = Int(s[r]), (1 ... 31).contains(d) else { return nil }
        return d
    }

    private static func firstFourDigitYear(in s: String) -> Int? {
        let p = try? NSRegularExpression(pattern: "(\\d{4})\\s*年", options: [])
        let ns = s as NSString
        guard let m = p?.firstMatch(in: s, options: [], range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: s),
              let y = Int(s[r]), y >= 1800, y <= 2100 else { return nil }
        return y
    }

    /// Four-digit year optionally followed by 春夏秋冬, or a lone year line.
    private static func fourDigitYearWithoutRequiredNian(in line: String) -> Int? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        let patterns = [
            "^(\\d{4})\\s*[春夏秋冬]$",
            "^(\\d{4})\\s*$"
        ]
        for pat in patterns {
            let p = try? NSRegularExpression(pattern: pat, options: [])
            let ns = t as NSString
            guard let m = p?.firstMatch(in: t, options: [], range: NSRange(location: 0, length: ns.length)),
                  m.numberOfRanges >= 2,
                  let r = Range(m.range(at: 1), in: t),
                  let y = Int(t[r]), y >= 1800, y <= 2100 else { continue }
            return y
        }
        return nil
    }

    private static func seasonMonth(in s: String) -> Int? {
        if s.contains("春") && !s.contains("秋冬") { return 3 }
        if s.contains("夏") { return 6 }
        if s.contains("秋") { return 9 }
        if s.contains("冬") { return 12 }
        return nil
    }

    private static func lunarMonth(in s: String) -> Int? {
        for (name, mo) in lunarMonthNames where s.contains(name) { return mo }
        return nil
    }
}
