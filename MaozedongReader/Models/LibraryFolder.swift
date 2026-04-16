import Foundation

/// User-defined library grouping under a category.
struct LibraryFolder: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var category: DocumentCategory
    var title: String
    /// Sort order within the same category (lower first).
    var sortOrder: Int

    init(id: UUID = UUID(), category: DocumentCategory, title: String, sortOrder: Int) {
        self.id = id
        self.category = category
        self.title = title
        self.sortOrder = sortOrder
    }
}
