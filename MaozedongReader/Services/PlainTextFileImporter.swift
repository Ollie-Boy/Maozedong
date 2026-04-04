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

        let encodings: [String.Encoding] = [
            .utf8,
            .unicode,
            .utf16LittleEndian,
            .utf16BigEndian,
            .gb_18030_2000
        ]

        let text = encodings.compactMap { encoding in
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
}
