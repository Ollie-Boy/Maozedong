import Foundation

/// Persisted scroll progress (UTF-16 offset into `DocumentItem.content`), bookmarks, snippets, and reading time.
struct ReaderStateSnapshot: Codable, Equatable {
    /// Last read position per document (`documentId` → UTF-16 offset).
    var progressUTF16ByDocumentId: [UUID: Int]
    var bookmarks: [BookmarkEntry]
    /// Long-press / selection excerpts with optional notes.
    var textSnippets: [TextSnippetEntry]
    /// Total seconds spent in reader per document (accumulated when leaving the page or backgrounding).
    var readingSecondsByDocumentId: [UUID: Int]
    var lastOpenedDocumentId: UUID?
    var lastOpenedAt: Date?

    static let empty = ReaderStateSnapshot(
        progressUTF16ByDocumentId: [:],
        bookmarks: [],
        textSnippets: [],
        readingSecondsByDocumentId: [:],
        lastOpenedDocumentId: nil,
        lastOpenedAt: nil
    )

    init(
        progressUTF16ByDocumentId: [UUID: Int] = [:],
        bookmarks: [BookmarkEntry] = [],
        textSnippets: [TextSnippetEntry] = [],
        readingSecondsByDocumentId: [UUID: Int] = [:],
        lastOpenedDocumentId: UUID? = nil,
        lastOpenedAt: Date? = nil
    ) {
        self.progressUTF16ByDocumentId = progressUTF16ByDocumentId
        self.bookmarks = bookmarks
        self.textSnippets = textSnippets
        self.readingSecondsByDocumentId = readingSecondsByDocumentId
        self.lastOpenedDocumentId = lastOpenedDocumentId
        self.lastOpenedAt = lastOpenedAt
    }

    enum CodingKeys: String, CodingKey {
        case progressUTF16ByDocumentId, bookmarks, textSnippets, readingSecondsByDocumentId
        case lastOpenedDocumentId, lastOpenedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        progressUTF16ByDocumentId = try c.decodeIfPresent([UUID: Int].self, forKey: .progressUTF16ByDocumentId) ?? [:]
        bookmarks = try c.decodeIfPresent([BookmarkEntry].self, forKey: .bookmarks) ?? []
        textSnippets = try c.decodeIfPresent([TextSnippetEntry].self, forKey: .textSnippets) ?? []
        readingSecondsByDocumentId = try c.decodeIfPresent([UUID: Int].self, forKey: .readingSecondsByDocumentId) ?? [:]
        lastOpenedDocumentId = try c.decodeIfPresent(UUID.self, forKey: .lastOpenedDocumentId)
        lastOpenedAt = try c.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(progressUTF16ByDocumentId, forKey: .progressUTF16ByDocumentId)
        try c.encode(bookmarks, forKey: .bookmarks)
        try c.encode(textSnippets, forKey: .textSnippets)
        try c.encode(readingSecondsByDocumentId, forKey: .readingSecondsByDocumentId)
        try c.encodeIfPresent(lastOpenedDocumentId, forKey: .lastOpenedDocumentId)
        try c.encodeIfPresent(lastOpenedAt, forKey: .lastOpenedAt)
    }
}
