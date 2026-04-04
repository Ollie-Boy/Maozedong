import Foundation

/// Persisted scroll progress (UTF-16 offset into `DocumentItem.content`) and bookmarks.
struct ReaderStateSnapshot: Codable, Equatable {
    /// Last read position per document (`documentId` → UTF-16 offset).
    var progressUTF16ByDocumentId: [UUID: Int]
    var bookmarks: [BookmarkEntry]

    static let empty = ReaderStateSnapshot(progressUTF16ByDocumentId: [:], bookmarks: [])

    init(progressUTF16ByDocumentId: [UUID: Int] = [:], bookmarks: [BookmarkEntry] = []) {
        self.progressUTF16ByDocumentId = progressUTF16ByDocumentId
        self.bookmarks = bookmarks
    }
}
