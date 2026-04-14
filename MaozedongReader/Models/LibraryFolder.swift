import Foundation

/// User-defined grouping under a category (e.g. custom “第一卷” for imported files).
struct LibraryFolder: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var category: DocumentCategory
    var title: String
    /// Lower values appear earlier in the library list (after uncategorized items).
    var sortOrder: Int

    init(id: UUID = UUID(), category: DocumentCategory, title: String, sortOrder: Int) {
        self.id = id
        self.category = category
        self.title = title
        self.sortOrder = sortOrder
    }
}
