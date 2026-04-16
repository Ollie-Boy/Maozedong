import Foundation

/// Inverted bigram/trigram index over title and preview; candidates verified by full string search.
struct LibrarySearchIndex: Sendable {
    private let bigramToIds: [String: Set<UUID>]
    private let trigramToIds: [String: Set<UUID>]

    /// Max characters of body preview indexed per document.
    static let indexPreviewCharCount = 12_000

    nonisolated static func build(rows: [(id: UUID, title: String, preview: String)]) -> LibrarySearchIndex {
        var bigram = [String: Set<UUID>]()
        var trigram = [String: Set<UUID>]()
        bigram.reserveCapacity(4096)
        trigram.reserveCapacity(8192)

        for row in rows {
            let s = (row.title + "\n" + String(row.preview.prefix(Self.indexPreviewCharCount))).lowercased()
            let chars = Array(s)
            guard chars.count >= 2 else { continue }
            for i in 0 ..< (chars.count - 1) {
                let b = String(chars[i ... i + 1])
                bigram[b, default: []].insert(row.id)
            }
            if chars.count >= 3 {
                for i in 0 ..< (chars.count - 2) {
                    let t = String(chars[i ... i + 2])
                    trigram[t, default: []].insert(row.id)
                }
            }
        }
        return LibrarySearchIndex(bigramToIds: bigram, trigramToIds: trigram)
    }

    /// `nil`: caller should scan all documents (short or empty query).
    nonisolated func candidateIds(for rawQuery: String) -> Set<UUID>? {
        let q = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        let chars = Array(q)
        if chars.count == 1 { return nil }
        if chars.count == 2 {
            return bigramToIds[String(chars[0 ... 1])] ?? []
        }
        let tris: [String] = (0 ..< (chars.count - 2)).map { i in String(chars[i ... i + 2]) }
        guard let first = tris.first else { return nil }
        var result = trigramToIds[first] ?? []
        for t in tris.dropFirst() {
            result = result.intersection(trigramToIds[t] ?? [])
            if result.isEmpty { return [] }
        }
        return result
    }
}
