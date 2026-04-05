import Foundation

/// Splits “时间/元信息”与正文首句（诗词：首行内日期+诗句；选集：# 标题后括号日期行）。
enum LeadLayoutNormalizer {
    // MARK: - Poetry (plain text main, before 注释)

    /// Returns optional second-line meta (bold in Markdown) and remaining poem body.
    static func splitPoetryMetaAndBody(mainRaw: String) -> (meta: String?, body: String) {
        let rawLines = mainRaw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var lines = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }
        while lines.first?.isEmpty == true { lines.removeFirst() }
        guard let first = lines.first, !first.isEmpty else {
            return (nil, mainRaw.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if let splitSameLine = splitDatePrefixFromLine(first) ?? splitDateGluedToPoemLine(first) {
            let restLines = Array(lines.dropFirst())
            let body = joinBodyLines(firstPoemFragment: splitSameLine.body, restLines: restLines)
            return (splitSameLine.meta, body)
        }

        if isStandalonePoetryMetaLine(first) {
            let rest = Array(lines.dropFirst()).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return (first, rest)
        }

        return (nil, mainRaw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func joinBodyLines(firstPoemFragment: String, restLines: [String]) -> String {
        var parts: [String] = []
        if !firstPoemFragment.isEmpty { parts.append(firstPoemFragment) }
        let tail = restLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { parts.append(tail) }
        return parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "1902年正月 狮子眼鼓鼓，…" → meta + body fragment
    private static func splitDatePrefixFromLine(_ line: String) -> (meta: String, body: String)? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard let range = t.range(of: "\\s+", options: .regularExpression) else { return nil }
        let left = String(t[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let right = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !left.isEmpty, !right.isEmpty else { return nil }
        guard looksLikePoetryDatePrefix(left) else { return nil }
        guard looksLikePoemTextStart(right) else { return nil }
        return (left, right)
    }

    /// e.g. `1949年4月七律·人民解放军占领南京`（日期与诗句之间无空格）
    private static func splitDateGluedToPoemLine(_ line: String) -> (meta: String, body: String)? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard let re = try? NSRegularExpression(
            pattern: #"^(\d{4}年(?:\d{1,2}月)?(?:\d{1,2}日)?)([\u4e00-\u9fff「《（].+)$"#,
            options: []
        ) else { return nil }
        let ns = t as NSString
        guard let m = re.firstMatch(in: t, options: [], range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 3,
              let r1 = Range(m.range(at: 1), in: t),
              let r2 = Range(m.range(at: 2), in: t) else { return nil }
        let left = String(t[r1])
        let right = String(t[r2]).trimmingCharacters(in: .whitespaces)
        guard looksLikePoetryDatePrefix(left), looksLikePoemTextStart(right) else { return nil }
        return (left, right)
    }

    private static func looksLikePoetryDatePrefix(_ s: String) -> Bool {
        if s.range(of: "\\d{4}\\s*年", options: .regularExpression) != nil { return true }
        if s.contains("正月") || s.contains("腊月") || s.contains("元月") { return true }
        if s.range(of: "^\\d{1,2}\\s*月\\s*\\d{1,2}\\s*日", options: .regularExpression) != nil { return true }
        if s.contains("年") && s.count <= 18 { return true }
        return false
    }

    private static func looksLikePoemTextStart(_ s: String) -> Bool {
        guard let c = s.first else { return false }
        if ("A" ... "Z").contains(c) || ("a" ... "z").contains(c) { return false }
        if c == "（" || c == "(" || c == "「" || c == "《" { return true }
        let scalar = String(c).unicodeScalars.first?.value ?? 0
        if scalar >= 0x4E00, scalar <= 0x9FFF { return true }
        return false
    }

    private static func isStandalonePoetryMetaLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return false }
        // Full calendar date on its own line, e.g. 1919年3月12日、1918年8月17日
        if t.range(of: #"^\d{4}年\d{1,2}月\d{1,2}日$"#, options: .regularExpression) != nil {
            return true
        }
        if t.contains("，") || t.contains("。") { return false }
        if t.count > 32 { return false }
        let comp = PoemDateExtractor.components(from: t + "\nx")
        if comp.year != nil { return true }
        if t.range(of: "^\\d{4}\\s*年", options: .regularExpression) != nil, t.count <= 24 { return true }
        return false
    }

    // MARK: - Anthology Markdown (# title + （日期）)

    static func normalizeAnthologyMarkdown(_ text: String) -> String {
        let n = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard let re = try? NSRegularExpression(
            pattern: #"(?m)^(#\s+[^\n]+)\s*\n\s*（([^）\n]+)）\s*\n"#,
            options: []
        ) else { return text }
        let full = NSRange(location: 0, length: (n as NSString).length)
        let out = NSMutableString(string: n)
        let matches = re.matches(in: n, options: [], range: full).reversed()
        for m in matches {
            guard m.numberOfRanges >= 3,
                  let r0 = Range(m.range(at: 0), in: n),
                  let r1 = Range(m.range(at: 1), in: n),
                  let r2 = Range(m.range(at: 2), in: n) else { continue }
            let titleLine = String(n[r1])
            let dateInner = String(n[r2])
            let replacement = "\(titleLine)\n\n**（\(dateInner)）**\n\n"
            out.replaceCharacters(in: m.range(at: 0), with: replacement)
        }
        return String(out)
    }
}
