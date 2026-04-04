import Foundation

enum PlainTextParagraphs {
    /// Paragraphs split on blank lines, with UTF-16 start offset in `fullText`.
    static func segments(from fullText: String) -> [(text: String, utf16Start: Int)] {
        let text = fullText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let rawParts = text.components(separatedBy: "\n\n")
        var result: [(String, Int)] = []
        var searchFrom = text.startIndex

        for part in rawParts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            guard let found = text.range(of: trimmed, range: searchFrom ..< text.endIndex)
                ?? text.range(of: trimmed)
            else { continue }

            guard let u16 = found.lowerBound.samePosition(in: text.utf16) else { continue }
            let offset = text.utf16.distance(from: text.utf16.startIndex, to: u16)
            result.append((trimmed, offset))
            searchFrom = found.upperBound
        }

        if result.isEmpty {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty, let r = text.range(of: t), let u16 = r.lowerBound.samePosition(in: text.utf16) {
                let offset = text.utf16.distance(from: text.utf16.startIndex, to: u16)
                result.append((t, offset))
            }
        }

        return result
    }
}
