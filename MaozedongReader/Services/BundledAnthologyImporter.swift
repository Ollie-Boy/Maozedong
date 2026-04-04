import Foundation

/// Offline copy of weiyinfu/MaoZeDongAnthology `src/*.md` (folder reference → app bundle).
enum BundledAnthologyImporter {
    static let sourcePrefix = "bundledAnthology:"

    static func loadDocuments() -> [DocumentItem] {
        let bundle = Bundle.main
        var urls = bundle.urls(forResourcesWithExtension: "md", subdirectory: "BundledAnthology") ?? []
        if urls.isEmpty {
            urls = (bundle.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? [])
                .filter { $0.path.contains("BundledAnthology") }
        }
        let sorted = urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var items: [DocumentItem] = []
        items.reserveCapacity(sorted.count)

        for url in sorted {
            let name = url.lastPathComponent
            guard let data = try? Data(contentsOf: url) else { continue }
            guard let text = decodeText(data: data), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            let (seq, title) = parseFileName(name)
            items.append(
                DocumentItem(
                    title: title,
                    content: text,
                    sourceFileName: "\(sourcePrefix)\(name)",
                    category: .anthology,
                    sortCorpusIndex: seq
                )
            )
        }

        return items
    }

    /// `000-标题.md` → (0, "标题")
    private static func parseFileName(_ name: String) -> (Int?, String) {
        guard name.lowercased().hasSuffix(".md") else { return (nil, name) }
        let base = String(name.dropLast(3))
        guard let dash = base.firstIndex(of: "-") else { return (nil, base) }
        let numPart = String(base[..<dash])
        let rest = String(base[base.index(after: dash)...])
        if numPart.count == 3, let n = Int(numPart) {
            return (n, rest)
        }
        return (nil, base)
    }

    private static func decodeText(data: Data) -> String? {
        ImportedFileEncoding.decodeCandidates.compactMap { String(data: data, encoding: $0) }.first
    }
}
