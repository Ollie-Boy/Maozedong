import Foundation

enum BundledPoetryImporter {
    private static let corpusSubdirectory = "Resources"
    private static let corpusFileName = "BundledPoetryCorpus"
    private static let corpusExtension = "txt"
    private static let partPrefix = "BundledPoetryCorpus_part"
    private static let partExtension = "txt"

    static func loadDocuments() -> [DocumentItem] {
        let bundle = Bundle.main
        let raw = loadRawCorpusText(from: bundle)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return PoetryCorpusParser.documents(from: trimmed, category: .poetry)
    }

    /// Xcode copies target resources to the **bundle root** by default, not into a `Resources/` folder.
    private static func loadRawCorpusText(from bundle: Bundle) -> String {
        func loadSingleFile(name: String, ext: String, subdirectory: String?) -> String? {
            guard let url = bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory),
                  let s = try? String(contentsOf: url, encoding: .utf8),
                  !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return s
        }

        if let s = loadSingleFile(name: corpusFileName, ext: corpusExtension, subdirectory: corpusSubdirectory)
            ?? loadSingleFile(name: corpusFileName, ext: corpusExtension, subdirectory: nil) {
            return s
        }

        var partURLs: [URL] = []
        for n in 1 ... 99 {
            let name = String(format: "%@%02d", partPrefix, n)
            if let u = bundle.url(forResource: name, withExtension: partExtension, subdirectory: corpusSubdirectory) {
                partURLs.append(u)
            } else if let u = bundle.url(forResource: name, withExtension: partExtension, subdirectory: nil) {
                partURLs.append(u)
            }
        }

        if partURLs.isEmpty, let all = bundle.urls(forResourcesWithExtension: partExtension, subdirectory: nil) {
            partURLs = all
                .filter { $0.lastPathComponent.hasPrefix(partPrefix) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        let chunks: [String] = partURLs.compactMap { url in
            try? String(contentsOf: url, encoding: .utf8)
        }
        return chunks.joined(separator: "\n\n")
    }
}
