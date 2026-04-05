import SwiftUI

enum InlineMarkdownFormatter {
    /// Plain text for VoiceOver (strips inline `**` / `` ` `` markup).
    static func accessibilityLineDescription(_ line: String) -> String {
        var t = line.replacingOccurrences(of: "**", with: "")
        while let open = t.firstIndex(of: "`") {
            let after = t.index(after: open)
            guard let close = t[after...].firstIndex(of: "`") else { break }
            let inner = String(t[after..<close])
            t.replaceSubrange(open...close, with: inner)
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Renders a single line with `**bold**` and `` `code` `` spans into an `AttributedString`.
    static func attributedLine(
        _ line: String,
        baseFontSize: CGFloat,
        textColor: Color,
        secondaryColor: Color
    ) -> AttributedString {
        var result = AttributedString()
        var i = line.startIndex
        let plainFont = ReaderTypography.bodyFont(size: baseFontSize)
        let boldFont = ReaderTypography.boldFont(size: baseFontSize)
        let codeFont = Font.system(size: baseFontSize * 0.92, design: .monospaced)

        func appendPlain(_ substr: Substring) {
            guard !substr.isEmpty else { return }
            var chunk = AttributedString(String(substr))
            chunk.font = plainFont
            chunk.foregroundColor = textColor
            result.append(chunk)
        }

        func parseCodeRuns(in segment: Substring) {
            var seg = segment
            while let tick = seg.firstIndex(of: "`") {
                appendPlain(seg[..<tick])
                let afterOpen = seg.index(after: tick)
                guard let close = seg[afterOpen...].firstIndex(of: "`") else {
                    appendPlain(seg[tick...])
                    return
                }
                let inner = seg[afterOpen..<close]
                var codeChunk = AttributedString(String(inner))
                codeChunk.font = codeFont
                codeChunk.foregroundColor = secondaryColor
                result.append(codeChunk)
                seg = seg[seg.index(after: close)...]
            }
            appendPlain(seg)
        }

        while let open = line[i...].firstIndex(of: "*") {
            let rest = line.index(after: open)
            guard rest < line.endIndex, line[rest] == "*" else {
                parseCodeRuns(in: line[i..<rest])
                i = rest
                continue
            }
            parseCodeRuns(in: line[i..<open])
            let afterStars = line.index(after: rest)
            guard let close = line[afterStars...].range(of: "**")?.lowerBound else {
                parseCodeRuns(in: line[i...])
                return result
            }
            let inner = line[afterStars..<close]
            var boldChunk = AttributedString(String(inner))
            boldChunk.font = boldFont
            boldChunk.foregroundColor = textColor
            result.append(boldChunk)
            i = line.index(close, offsetBy: 2)
        }
        parseCodeRuns(in: line[i...])
        return result
    }
}
