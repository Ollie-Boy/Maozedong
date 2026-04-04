import Foundation

enum BundledPoetryImporter {
    private static let corpusSubdirectory = "Resources"
    private static let corpusFileName = "BundledPoetryCorpus"
    private static let corpusExtension = "txt"

    /// Concatenated parts `BundledPoetryCorpus_part01.txt` … in bundle (optional).
    private static let partPrefix = "BundledPoetryCorpus_part"
    private static let partExtension = "txt"

    static func loadDocuments() -> [DocumentItem] {
        let bundle = Bundle.main
        var raw = ""

        if let url = bundle.url(forResource: corpusFileName, withExtension: corpusExtension, subdirectory: corpusSubdirectory),
           let s = try? String(contentsOf: url, encoding: .utf8), !s.isEmpty {
            raw = s
        }

        if raw.isEmpty {
            let partURLs = (1 ... 99).compactMap { n -> URL? in
                let name = String(format: "%@%02d", partPrefix, n)
                return bundle.url(forResource: name, withExtension: partExtension, subdirectory: corpusSubdirectory)
            }
            let chunks: [String] = partURLs.compactMap { url in
                try? String(contentsOf: url, encoding: .utf8)
            }
            raw = chunks.joined(separator: "\n\n")
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return PoetryCorpusParser.documents(from: trimmed, category: .poetry)
    }
}
