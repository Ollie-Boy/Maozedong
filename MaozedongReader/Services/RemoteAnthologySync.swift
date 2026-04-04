import Foundation

/// Fetches Markdown from [weiyinfu/MaoZeDongAnthology](https://github.com/weiyinfu/MaoZeDongAnthology) `src/`.
enum RemoteAnthologySync {
    static let owner = "weiyinfu"
    static let repo = "MaoZeDongAnthology"
    static let branch = "master"
    static let srcPath = "src"
    static let sourcePrefix = "remoteAnthology:weiyinfu/MaoZeDongAnthology:"

    private struct GitHubContentEntry: Decodable {
        let name: String
        let type: String
        let download_url: String?
    }

    private static var listURL: URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(srcPath)?ref=\(branch)")!
    }

    /// One (or paginated) GitHub API `contents` call, then batched parallel raw downloads.
    static func fetchDocuments(batchSize: Int = 5) async throws -> [DocumentItem] {
        var allEntries: [GitHubContentEntry] = []
        var nextURL: URL? = listURL

        while let url = nextURL {
            var req = URLRequest(url: url)
            req.setValue("MaozedongReader/1.0", forHTTPHeaderField: "User-Agent")
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let page = try JSONDecoder().decode([GitHubContentEntry].self, from: data)
            allEntries.append(contentsOf: page)
            nextURL = parseNextPageURL(from: http.value(forHTTPHeaderField: "Link"))
        }

        let mdFiles = allEntries.filter { $0.type == "file" && $0.name.lowercased().hasSuffix(".md") }
        guard !mdFiles.isEmpty else { return [] }

        var results: [DocumentItem] = []
        results.reserveCapacity(mdFiles.count)

        var idx = mdFiles.startIndex
        while idx < mdFiles.endIndex {
            let end = mdFiles.index(idx, offsetBy: batchSize, limitedBy: mdFiles.endIndex) ?? mdFiles.endIndex
            let slice = Array(mdFiles[idx ..< end])
            idx = end

            let batch = try await withThrowingTaskGroup(of: DocumentItem?.self) { group in
                for f in slice {
                    group.addTask { try await downloadOne(f) }
                }
                var acc: [DocumentItem] = []
                for try await item in group {
                    if let d = item { acc.append(d) }
                }
                return acc
            }
            results.append(contentsOf: batch)
        }

        return results.sorted(by: DocumentItem.displaySort)
    }

    private static func parseNextPageURL(from linkHeader: String?) -> URL? {
        guard let h = linkHeader else { return nil }
        for part in h.split(separator: ",") {
            let s = String(part).trimmingCharacters(in: .whitespaces)
            guard s.hasSuffix("rel=\"next\"") else { continue }
            guard let start = s.firstIndex(of: "<"),
                  let end = s.firstIndex(of: ">") else { continue }
            let urlStr = String(s[s.index(after: start) ..< end])
            return URL(string: urlStr)
        }
        return nil
    }

    private static func downloadOne(_ entry: GitHubContentEntry) async throws -> DocumentItem? {
        guard let rawStr = entry.download_url, let rawURL = URL(string: rawStr) else { return nil }

        var req = URLRequest(url: rawURL)
        req.setValue("MaozedongReader/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            return nil
        }

        guard let text = decodeText(data: data), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let (seq, title) = parseFileName(entry.name)
        return DocumentItem(
            title: title,
            content: text,
            sourceFileName: "\(sourcePrefix)\(entry.name)",
            category: .anthology,
            sortCorpusIndex: seq
        )
    }

    /// `000-标题.md` → (0, "标题")
    static func parseFileName(_ name: String) -> (Int?, String) {
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
