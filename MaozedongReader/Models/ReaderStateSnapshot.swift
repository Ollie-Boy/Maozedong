import Foundation

/// Persisted scroll progress (UTF-16 offset into `DocumentItem.content`) and bookmarks.
struct ReaderStateSnapshot: Codable, Equatable {
    /// Last read position per document (`documentId` → UTF-16 offset).
    var progressUTF16ByDocumentId: [UUID: Int]
    var bookmarks: [BookmarkEntry]
    var lastOpenedDocumentId: UUID?
    var lastOpenedAt: Date?

    static let empty = ReaderStateSnapshot(
        progressUTF16ByDocumentId: [:],
        bookmarks: [],
        lastOpenedDocumentId: nil,
        lastOpenedAt: nil
    )

    init(
        progressUTF16ByDocumentId: [UUID: Int] = [:],
        bookmarks: [BookmarkEntry] = [],
        lastOpenedDocumentId: UUID? = nil,
        lastOpenedAt: Date? = nil
    ) {
        self.progressUTF16ByDocumentId = progressUTF16ByDocumentId
        self.bookmarks = bookmarks
        self.lastOpenedDocumentId = lastOpenedDocumentId
        self.lastOpenedAt = lastOpenedAt
    }

    enum CodingKeys: String, CodingKey {
        case progressUTF16ByDocumentId, bookmarks, lastOpenedDocumentId, lastOpenedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        progressUTF16ByDocumentId = try c.decodeIfPresent([UUID: Int].self, forKey: .progressUTF16ByDocumentId) ?? [:]
        bookmarks = try c.decodeIfPresent([BookmarkEntry].self, forKey: .bookmarks) ?? []
        lastOpenedDocumentId = try c.decodeIfPresent(UUID.self, forKey: .lastOpenedDocumentId)
        lastOpenedAt = try c.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(progressUTF16ByDocumentId, forKey: .progressUTF16ByDocumentId)
        try c.encode(bookmarks, forKey: .bookmarks)
        try c.encodeIfPresent(lastOpenedDocumentId, forKey: .lastOpenedDocumentId)
        try c.encodeIfPresent(lastOpenedAt, forKey: .lastOpenedAt)
    }
}
