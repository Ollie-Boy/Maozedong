import Foundation

/// Parses bundled plain text where each work starts with a line `序号 标题` (e.g. `28 沁园春·长沙`).
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
                  let titleRange = Range(m.range(at: 2), in: text) else { continue }

            let titleLine = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let start = m.range.location
            let end = i + 1 < matches.count ? matches[i + 1].range.location : ns.length
            let block = ns.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let body = dropFirstLine(block).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }

            let markdown = """
            # \(titleLine)

            \(body)
            """

            let safeSlug = titleLine
                .replacingOccurrences(of: "/", with: "-")
                .prefix(40)
            let sourceName = "bundled_poetry_\(String(safeSlug)).txt"

            items.append(
                DocumentItem(
                    title: titleLine,
                    content: markdown,
                    sourceFileName: String(sourceName),
                    category: category
                )
            )
        }

        return items
    }

    private static func dropFirstLine(_ s: String) -> String {
        guard let idx = s.firstIndex(of: "\n") else { return "" }
        return String(s[s.index(after: idx)...])
    }
}
