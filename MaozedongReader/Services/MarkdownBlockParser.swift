import Foundation

struct MarkdownBlock: Identifiable, Equatable {
    enum Kind: Equatable {
        case heading(level: Int, text: String)
        case paragraph(lines: [String])
        case blockquote(lines: [String])
        case bullet(items: [String])
        case ordered(items: [String])
        case horizontalRule
        /// Collapsed 注释 body (after `---` + `## 注释`); rendered as footnote-style region.
        case noteSection(lines: [String])
    }

    let id: UUID
    var kind: Kind
    /// For plain-text (non-Markdown) segments: UTF-16 offset in the original document string.
    var plainUTF16Start: Int?

    init(id: UUID = UUID(), kind: Kind, plainUTF16Start: Int? = nil) {
        self.id = id
        self.kind = kind
        self.plainUTF16Start = plainUTF16Start
    }
}

extension MarkdownBlock {
    /// UTF-16 start offset of this block within the original source string.
    func utf16StartOffset(in source: String) -> Int? {
        if let p = plainUTF16Start { return p }
        guard let r = MarkdownBlockParser.rangeOfBlock(self, in: source),
              let u16 = r.lowerBound.samePosition(in: source.utf16) else { return nil }
        return source.utf16.distance(from: source.utf16.startIndex, to: u16)
    }

    func plainTextLines() -> [String] {
        switch kind {
        case let .heading(_, text):
            return [text]
        case let .paragraph(lines):
            return lines
        case let .blockquote(lines):
            return lines
        case let .bullet(items):
            return items
        case let .ordered(items):
            return items
        case .horizontalRule:
            return []
        case let .noteSection(lines):
            return lines
        }
    }
}

enum MarkdownBlockParser {
    static func parse(_ text: String) -> [MarkdownBlock] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [MarkdownBlock] = []
        var i = 0

        while i < rawLines.count {
            let line = rawLines[i]

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }

            if isThematicBreak(line) {
                blocks.append(MarkdownBlock(kind: .horizontalRule))
                i += 1
                continue
            }

            if let level = headingLevel(line) {
                let title = String(line.dropFirst(level + 1)).trimmingCharacters(in: .whitespaces)
                blocks.append(MarkdownBlock(kind: .heading(level: level, text: title)))
                i += 1
                continue
            }

            if line.hasPrefix("> ") || line == ">" {
                var q: [String] = []
                while i < rawLines.count {
                    let l = rawLines[i]
                    if l.trimmingCharacters(in: .whitespaces).isEmpty { break }
                    if l.hasPrefix("> ") {
                        q.append(String(l.dropFirst(2)))
                        i += 1
                    } else if l == ">" {
                        q.append("")
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(MarkdownBlock(kind: .blockquote(lines: q)))
                continue
            }

            if unorderedItemLine(line) != nil {
                var items: [String] = []
                while i < rawLines.count, let item = unorderedItemLine(rawLines[i]) {
                    items.append(item)
                    i += 1
                }
                blocks.append(MarkdownBlock(kind: .bullet(items: items)))
                continue
            }

            if let item = orderedItemLine(line) {
                var items: [String] = [item]
                i += 1
                while i < rawLines.count, let next = orderedItemLine(rawLines[i]) {
                    items.append(next)
                    i += 1
                }
                blocks.append(MarkdownBlock(kind: .ordered(items: items)))
                continue
            }

            var para: [String] = [line]
            i += 1
            while i < rawLines.count {
                let l = rawLines[i]
                if l.trimmingCharacters(in: .whitespaces).isEmpty { break }
                if headingLevel(l) != nil || isThematicBreak(l) { break }
                if l.hasPrefix("> ") || l == ">" { break }
                if unorderedItemLine(l) != nil { break }
                if orderedItemLine(l) != nil { break }
                para.append(l)
                i += 1
            }
            blocks.append(MarkdownBlock(kind: .paragraph(lines: para)))
        }

        return postprocessPoetryNotes(blocks)
    }

    /// Merges `---` + `## 注释` + following paragraphs into a single `.noteSection` for collapsible footnote UI.
    private static func postprocessPoetryNotes(_ blocks: [MarkdownBlock]) -> [MarkdownBlock] {
        var out: [MarkdownBlock] = []
        var i = 0
        while i < blocks.count {
            if i + 2 < blocks.count,
               case .horizontalRule = blocks[i].kind,
               case let .heading(level, text) = blocks[i + 1].kind,
               level == 2,
               text == "注释" {
                var lines: [String] = []
                var j = i + 2
                while j < blocks.count, case let .paragraph(ls) = blocks[j].kind {
                    lines.append(contentsOf: ls)
                    j += 1
                }
                out.append(MarkdownBlock(id: blocks[i + 1].id, kind: .noteSection(lines: lines)))
                i = j
                continue
            }
            out.append(blocks[i])
            i += 1
        }
        return out
    }

    static func plainText(from blocks: [MarkdownBlock]) -> String {
        blocks.flatMap { $0.plainTextLines() }.joined(separator: "\n")
    }

    static func rangeOfBlock(_ block: MarkdownBlock, in source: String) -> Range<String.Index>? {
        let blocks = parse(source)
        guard let idx = blocks.firstIndex(where: { $0.id == block.id }) else { return nil }
        let ns = source as NSString
        let full = NSRange(location: 0, length: ns.length)

        func findSubstring(_ substring: String) -> Range<String.Index>? {
            guard !substring.isEmpty else { return nil }
            var searchRange = full
            while searchRange.length > 0 {
                let r = ns.range(of: substring, options: [], range: searchRange)
                if r.location == NSNotFound { return nil }
                if let swift = Range(r, in: source) { return swift }
                searchRange = NSRange(location: r.location + 1, length: ns.length - r.location - 1)
            }
            return nil
        }

        let needle: String
        switch block.kind {
        case let .heading(_, text):
            needle = text
        case let .paragraph(lines):
            needle = lines.first ?? ""
        case let .blockquote(lines):
            needle = lines.first ?? ""
        case let .bullet(items):
            needle = items.first ?? ""
        case let .ordered(items):
            needle = items.first ?? ""
        case .horizontalRule:
            needle = "---"
        case let .noteSection(lines):
            needle = lines.first ?? ""
        }

        guard let startRange = findSubstring(needle) else { return nil }
        let start = startRange.lowerBound

        let end: String.Index
        if idx + 1 < blocks.count {
            let next = blocks[idx + 1]
            let nextNeedle: String
            switch next.kind {
            case let .heading(_, t): nextNeedle = t
            case let .paragraph(ls): nextNeedle = ls.first ?? ""
            case let .blockquote(ls): nextNeedle = ls.first ?? ""
            case let .bullet(items): nextNeedle = items.first ?? ""
            case let .ordered(items): nextNeedle = items.first ?? ""
            case .horizontalRule: nextNeedle = "---"
            case let .noteSection(ls): nextNeedle = ls.first ?? ""
            }
            if let nr = findSubstring(nextNeedle), nr.lowerBound > start {
                end = nr.lowerBound
            } else {
                end = source.endIndex
            }
        } else {
            end = source.endIndex
        }

        return start..<end
    }

    private static func isThematicBreak(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        let allowed = Set<Character>(["-", "*", "_", " "])
        guard t.allSatisfy({ allowed.contains($0) }) else { return false }
        let stripped = t.replacingOccurrences(of: " ", with: "")
        return stripped.count >= 3 && stripped.allSatisfy { $0 == stripped.first }
    }

    private static func headingLevel(_ line: String) -> Int? {
        if line.hasPrefix("###### ") { return 6 }
        if line.hasPrefix("##### ") { return 5 }
        if line.hasPrefix("#### ") { return 4 }
        if line.hasPrefix("### ") { return 3 }
        if line.hasPrefix("## ") { return 2 }
        if line.hasPrefix("# ") { return 1 }
        return nil
    }

    private static func unorderedItemLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") { return String(trimmed.dropFirst(2)) }
        if trimmed.hasPrefix("* ") { return String(trimmed.dropFirst(2)) }
        if trimmed.hasPrefix("+ ") { return String(trimmed.dropFirst(2)) }
        return nil
    }

    private static func orderedItemLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let dot = trimmed.firstIndex(of: ".") else { return nil }
        let prefix = trimmed[..<dot]
        guard !prefix.isEmpty, prefix.allSatisfy({ $0.isNumber }) else { return nil }
        let after = trimmed[trimmed.index(after: dot)...].drop(while: { $0 == " " })
        return String(after)
    }
}
