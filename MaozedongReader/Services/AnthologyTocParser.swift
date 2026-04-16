import Foundation

/// Parses bundled anthology table-of-contents markdown.
enum AnthologyTocParser {
    struct Entry {
        /// Subsection title; equals major title when the TOC has no subsection.
        let sectionTitle: String
        /// Major volume title for library grouping.
        let majorTitle: String
        let majorOrder: Int
        let subOrder: Int
    }

    /// Index key is the markdown file name without path.
    static func indexByFileName(bundle: Bundle) -> [String: Entry] {
        guard let url = bundle.url(forResource: "AnthologyTOC", withExtension: "md", subdirectory: "Resources")
            ?? bundle.url(forResource: "AnthologyTOC", withExtension: "md", subdirectory: nil) else {
            return [:]
        }
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .unicode) else {
            return [:]
        }
        return parse(text)
    }

    static func parse(_ text: String) -> [String: Entry] {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var majorOrder = 0
        var subOrderCounter = 0
        var currentMajor = ""
        var currentSub = ""
        var result: [String: Entry] = [:]

        let linkPattern = try? NSRegularExpression(pattern: #"^\*\s*\[[^\]]*\]\(\./([^)]+\.md)\)"#, options: [])

        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("# ") && !t.hasPrefix("## ") {
                majorOrder += 1
                subOrderCounter = 0
                currentMajor = String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                currentSub = ""
                continue
            }
            if t.hasPrefix("## ") {
                subOrderCounter += 1
                currentSub = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                continue
            }

            let ns = t as NSString
            guard let re = linkPattern,
                  let m = re.firstMatch(in: t, options: [], range: NSRange(location: 0, length: ns.length)),
                  m.numberOfRanges >= 2,
                  let r = Range(m.range(at: 1), in: t) else { continue }

            let fileName = String(t[r])
            let sectionTitle: String
            let subOrd: Int
            if currentSub.isEmpty {
                sectionTitle = currentMajor
                subOrd = 0
            } else {
                sectionTitle = currentSub
                subOrd = subOrderCounter
            }

            result[fileName] = Entry(
                sectionTitle: sectionTitle,
                majorTitle: currentMajor,
                majorOrder: majorOrder,
                subOrder: subOrd
            )
        }

        return result
    }
}
