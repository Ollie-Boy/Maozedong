import Foundation

struct BookmarkEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var documentId: UUID
    /// UTF-16 offset into `DocumentItem.content` for stable restore after minor edits.
    var utf16Offset: Int
    /// Short label shown in the list (e.g. heading or line preview).
    var label: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        documentId: UUID,
        utf16Offset: Int,
        label: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.documentId = documentId
        self.utf16Offset = utf16Offset
        self.label = label
        self.createdAt = createdAt
    }
}
