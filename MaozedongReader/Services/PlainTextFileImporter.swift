import CoreFoundation
import Foundation
import UniformTypeIdentifiers

enum ImportError: Error, LocalizedError {
    case invalidEncoding
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "文件编码无法识别，请使用 UTF-8 / GB18030 等常见编码。"
        case .emptyFile:
            return "文件内容为空。"
        }
    }
}

struct ImportedTextFile {
    let title: String
    let content: String
}

private enum ImportedFileEncoding {
    /// GB18030 via CoreFoundation (numeric code: same as `kCFStringEncodingGB_18030_2000`).
    /// Some toolchains omit both the Swift `String.Encoding` alias and the C macro in scope.
    static var gb18030: String.Encoding? {
        let cf: CFStringEncoding = 0x0632 // GB18030-2000
        let ns = CFStringConvertEncodingToNSStringEncoding(cf)
        guard ns != UInt(bitPattern: -1) else { return nil }
        return String.Encoding(rawValue: ns)
    }

    static var decodeCandidates: [String.Encoding] {
        var encodings: [String.Encoding] = [
            .utf8,
            .unicode,
            .utf16LittleEndian,
            .utf16BigEndian
        ]
        if let gb = gb18030 {
            encodings.append(gb)
        }
        return encodings
    }
}

enum PlainTextFileImporter {
    static var supportedContentTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        if let markdown = UTType(filenameExtension: "md") {
            types.append(markdown)
        }
        return types
    }

    static func parse(url: URL) throws -> ImportedTextFile {
        let fileName = url.deletingPathExtension().lastPathComponent
        let data = try Data(contentsOf: url)

        let text = ImportedFileEncoding.decodeCandidates.compactMap { encoding in
            String(data: data, encoding: encoding)
        }.first?.replacingOccurrences(of: "\r\n", with: "\n")
          .replacingOccurrences(of: "\r", with: "\n")
          .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !text.isEmpty else {
            if data.isEmpty { throw ImportError.emptyFile }
            throw ImportError.invalidEncoding
        }

        return ImportedTextFile(title: fileName, content: text)
    }

    // Keep a string-only helper for call sites that only need content.
    static func read(from url: URL) throws -> String {
        try parse(url: url).content
    }

    static func inferredCategory(fileName: String, content: String) -> DocumentCategory {
        let lower = fileName.lowercased()
        if lower.contains("诗") || lower.contains("词") || lower.contains("poem") {
            return .poetry
        }
        if lower.contains("语录") || lower.contains("quote") {
            return .quote
        }
        if lower.contains("选集") || lower.contains("anthology") {
            return .anthology
        }
        if lower.contains("文") || lower.contains("article") || lower.hasSuffix(".md") {
            return .article
        }
        let c = content
        if c.count < 800, c.split(separator: "\n").count <= 12 {
            return .quote
        }
        return .article
    }
}
