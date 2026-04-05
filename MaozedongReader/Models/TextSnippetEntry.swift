import Foundation

/// User-selected passage (UTF-16 range in `DocumentItem.content`); optional note.
struct TextSnippetEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var documentId: UUID
    var utf16Start: Int
    var utf16End: Int
    /// Preview of selected text (denormalized).
    var excerpt: String
    var note: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        documentId: UUID,
        utf16Start: Int,
        utf16End: Int,
        excerpt: String,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.documentId = documentId
        self.utf16Start = utf16Start
        self.utf16End = utf16End
        self.excerpt = excerpt
        self.note = note
        self.createdAt = createdAt
    }
}
