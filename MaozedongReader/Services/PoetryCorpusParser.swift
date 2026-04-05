import Foundation

/// Parses bundled plain text: each work starts with `序号 标题` (e.g. `28 沁园春·长沙`).
enum PoetryCorpusParser {
    static func documents(from raw: String, category: DocumentCategory = .poetry) -> [DocumentItem] {
        let text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { return [] }

        let pattern = "(?m)^(\\d{1,3})\\s+(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }

        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: text, options: [], range: full)
        guard !matches.isEmpty else { return [] }

        var items: [DocumentItem] = []
        items.reserveCapacity(matches.count)

        for i in matches.indices {
            let m = matches[i]
            guard m.numberOfRanges >= 3,
                  let idxRange = Range(m.range(at: 1), in: text),
                  let titleRange = Range(m.range(at: 2), in: text),
                  let corpusIndex = Int(String(text[idxRange])) else { continue }

            let titleLine = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let start = m.range.location
            let end = i + 1 < matches.count ? matches[i + 1].range.location : ns.length
            let block = ns.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let body = dropFirstLine(block).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }

            let (mainRaw, noteRaw) = splitMainAndAnnotation(body)
            let comp = PoemDateExtractor.components(from: mainRaw)

            let markdown = buildMarkdown(title: titleLine, main: mainRaw, note: noteRaw)

            let safeSlug = titleLine
                .replacingOccurrences(of: "/", with: "-")
                .prefix(40)
            let sourceName = "bundled_poetry_\(String(safeSlug)).txt"

            items.append(
                DocumentItem(
                    title: titleLine,
                    content: markdown,
                    sourceFileName: String(sourceName),
                    category: category,
                    sortEpochYear: comp.year,
                    sortEpochMonth: comp.month,
                    sortEpochDay: comp.day,
                    sortCorpusIndex: corpusIndex
                )
            )
        }

        return items
    }

    private static func splitMainAndAnnotation(_ body: String) -> (String, String?) {
        let markers = ["注释：", "注释:"]
        var cut: String.Index?
        for mark in markers {
            if let r = body.range(of: mark) {
                if cut == nil || r.lowerBound < cut! {
                    cut = r.lowerBound
                }
            }
        }
        guard let c = cut else {
            return (body, nil)
        }
        let main = String(body[..<c]).trimmingCharacters(in: .whitespacesAndNewlines)
        let note = String(body[c...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if note.isEmpty { return (main, nil) }
        return (main, note)
    }

    private static func buildMarkdown(title: String, main: String, note: String?) -> String {
        let mainMd = main
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .joined(separator: "  \n")

        guard let note, !note.isEmpty else {
            return """
            # \(title)

            \(mainMd)
            """
        }

        let citationLine = annotationCitationLine(from: note) ?? note
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty }) ?? ""

        guard !citationLine.isEmpty else {
            return """
            # \(title)

            \(mainMd)
            """
        }

        return """
        # \(title)

        \(mainMd)

        ---

        ## 注释

        \(citationLine)
        """
    }

    /// Keeps only the first non-empty line of the annotation block (出版来源等)，去掉其后解读性正文。
    private static func annotationCitationLine(from note: String) -> String? {
        let lines = note.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
        guard let first = lines.first(where: { !$0.isEmpty }) else { return nil }
        return first
    }

    private static func dropFirstLine(_ s: String) -> String {
        guard let idx = s.firstIndex(of: "\n") else { return "" }
        return String(s[s.index(after: idx)...])
    }
}
