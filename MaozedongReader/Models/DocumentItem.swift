import Foundation

struct DocumentItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    /// Inline body when not externalized; otherwise load via `DocumentStore.resolvedBody`.
    var content: String
    /// Large bodies are stored on disk; JSON keeps metadata and preview only.
    var contentExternalized: Bool
    /// Body prefix for search and markdown detection when full body is not in memory.
    var contentPreview: String?
    var sourceFileName: String?
    var category: DocumentCategory
    /// Calendar fields for chronological sort.
    var sortEpochYear: Int?
    var sortEpochMonth: Int?
    var sortEpochDay: Int?
    /// Bundled poetry sequence; tie-breaker when dates match.
    var sortCorpusIndex: Int?
    /// Anthology subsection title from TOC.
    var anthologySectionTitle: String?
    /// Anthology major volume title from TOC.
    var anthologyMajorTitle: String?
    var anthologyMajorOrder: Int?
    var anthologySubOrder: Int?
    /// Optional user library folder id.
    var libraryFolderId: UUID?
    /// Folder sort order cache for stable `displaySort`.
    var libraryFolderSortKey: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, content, contentExternalized, contentPreview, sourceFileName, category
        case sortEpochYear, sortEpochMonth, sortEpochDay, sortCorpusIndex
        case anthologySectionTitle, anthologyMajorTitle, anthologyMajorOrder, anthologySubOrder
        case libraryFolderId, libraryFolderSortKey
        case createdAt, updatedAt
    }

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        contentExternalized: Bool = false,
        contentPreview: String? = nil,
        sourceFileName: String? = nil,
        category: DocumentCategory = .anthology,
        sortEpochYear: Int? = nil,
        sortEpochMonth: Int? = nil,
        sortEpochDay: Int? = nil,
        sortCorpusIndex: Int? = nil,
        anthologySectionTitle: String? = nil,
        anthologyMajorTitle: String? = nil,
        anthologyMajorOrder: Int? = nil,
        anthologySubOrder: Int? = nil,
        libraryFolderId: UUID? = nil,
        libraryFolderSortKey: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.contentExternalized = contentExternalized
        self.contentPreview = contentPreview
        self.sourceFileName = sourceFileName
        self.category = category
        self.sortEpochYear = sortEpochYear
        self.sortEpochMonth = sortEpochMonth
        self.sortEpochDay = sortEpochDay
        self.sortCorpusIndex = sortCorpusIndex
        self.anthologySectionTitle = anthologySectionTitle
        self.anthologyMajorTitle = anthologyMajorTitle
        self.anthologyMajorOrder = anthologyMajorOrder
        self.anthologySubOrder = anthologySubOrder
        self.libraryFolderId = libraryFolderId
        self.libraryFolderSortKey = libraryFolderSortKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        content = try c.decode(String.self, forKey: .content)
        contentExternalized = try c.decodeIfPresent(Bool.self, forKey: .contentExternalized) ?? false
        contentPreview = try c.decodeIfPresent(String.self, forKey: .contentPreview)
        sourceFileName = try c.decodeIfPresent(String.self, forKey: .sourceFileName)
        sortEpochYear = try c.decodeIfPresent(Int.self, forKey: .sortEpochYear)
        sortEpochMonth = try c.decodeIfPresent(Int.self, forKey: .sortEpochMonth)
        sortEpochDay = try c.decodeIfPresent(Int.self, forKey: .sortEpochDay)
        sortCorpusIndex = try c.decodeIfPresent(Int.self, forKey: .sortCorpusIndex)
        anthologySectionTitle = try c.decodeIfPresent(String.self, forKey: .anthologySectionTitle)
        anthologyMajorTitle = try c.decodeIfPresent(String.self, forKey: .anthologyMajorTitle)
        anthologyMajorOrder = try c.decodeIfPresent(Int.self, forKey: .anthologyMajorOrder)
        anthologySubOrder = try c.decodeIfPresent(Int.self, forKey: .anthologySubOrder)
        libraryFolderId = try c.decodeIfPresent(UUID.self, forKey: .libraryFolderId)
        libraryFolderSortKey = try c.decodeIfPresent(Int.self, forKey: .libraryFolderSortKey) ?? 0

        if let cat = try c.decodeIfPresent(DocumentCategory.self, forKey: .category) {
            category = cat
        } else if let raw = try c.decodeIfPresent(String.self, forKey: .category) {
            if raw == "quote" || raw == "article" {
                category = .anthology
            } else {
                category = DocumentCategory(rawValue: raw) ?? .anthology
            }
        } else {
            category = .anthology
        }

        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(content, forKey: .content)
        try c.encode(contentExternalized, forKey: .contentExternalized)
        try c.encodeIfPresent(contentPreview, forKey: .contentPreview)
        try c.encodeIfPresent(sourceFileName, forKey: .sourceFileName)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(sortEpochYear, forKey: .sortEpochYear)
        try c.encodeIfPresent(sortEpochMonth, forKey: .sortEpochMonth)
        try c.encodeIfPresent(sortEpochDay, forKey: .sortEpochDay)
        try c.encodeIfPresent(sortCorpusIndex, forKey: .sortCorpusIndex)
        try c.encodeIfPresent(anthologySectionTitle, forKey: .anthologySectionTitle)
        try c.encodeIfPresent(anthologyMajorTitle, forKey: .anthologyMajorTitle)
        try c.encodeIfPresent(anthologyMajorOrder, forKey: .anthologyMajorOrder)
        try c.encodeIfPresent(anthologySubOrder, forKey: .anthologySubOrder)
        try c.encodeIfPresent(libraryFolderId, forKey: .libraryFolderId)
        try c.encode(libraryFolderSortKey, forKey: .libraryFolderSortKey)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }

    /// Horizontal pager grouping key for bundled anthology volumes.
    var anthologyScrollGroupKey: String {
        guard category == .anthology,
              let m = anthologyMajorOrder,
              let s = anthologySubOrder else {
            return "anthology:\(id.uuidString)"
        }
        return "bundledAnthology:\(m):\(s)"
    }

    /// Text scanned for library search; title is searched separately.
    var textForLibrarySearch: String {
        if contentExternalized {
            return contentPreview ?? ""
        }
        return content
    }

    var contentNormalized: String {
        content.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True for built-in anthology files (bundled source prefix).
    var isBundledAnthology: Bool {
        sourceFileName?.hasPrefix("bundledAnthology:") == true
    }

    var isLikelyMarkdown: Bool {
        if let name = sourceFileName?.lowercased(), name.hasSuffix(".md") { return true }
        // Externalized: prefer inline `content` when present; else use preview for markdown heuristics.
        let s: String
        if contentExternalized {
            if !content.isEmpty {
                s = content
            } else {
                s = contentPreview ?? ""
            }
        } else {
            s = content
        }
        if s.contains("\n# ") || s.contains("\n## ") { return true }
        if s.hasPrefix("# ") || s.hasPrefix("## ") { return true }
        if s.contains("\n> ") || s.hasPrefix("> ") { return true }
        if s.contains("\n- ") || s.contains("\n* ") { return true }
        if s.contains("\n1. ") { return true }
        return false
    }

    /// Fills missing poetry sort fields from body text; use resolvedBody when inline content is empty.
    mutating func backfillPoetrySortMetadataFromContentIfNeeded(resolvedBody: String? = nil) {
        guard category == .poetry else { return }
        var body = resolvedBody ?? content
        if body.isEmpty, contentExternalized { return }
        if body.hasPrefix("# ") {
            if let nl = body.firstIndex(of: "\n") {
                body = String(body[body.index(after: nl)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if sortEpochYear == nil {
            let comp = PoemDateExtractor.components(from: body)
            sortEpochYear = comp.year
            sortEpochMonth = comp.month
            sortEpochDay = comp.day
        }
    }
}

extension DocumentItem {
    static let previewItems: [DocumentItem] = [
        DocumentItem(
            title: "示例：沁园春·雪",
            content: """
            # 示例：沁园春·雪

            1936年2月

            北国风光，千里冰封，万里雪飘。
            """,
            sourceFileName: "sample.txt",
            category: .poetry,
            sortEpochYear: 1936,
            sortEpochMonth: 2,
            sortCorpusIndex: 51
        )
    ]
}
