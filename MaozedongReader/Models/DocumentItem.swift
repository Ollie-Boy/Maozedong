import Foundation

struct DocumentItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var sourceFileName: String?
    var category: DocumentCategory
    /// Rough calendar fields for chronological sort (from corpus date line).
    var sortEpochYear: Int?
    var sortEpochMonth: Int?
    var sortEpochDay: Int?
    /// Original corpus sequence number (1…n) when from bundled poetry; tie-breaker when dates match.
    var sortCorpusIndex: Int?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, content, sourceFileName, category
        case sortEpochYear, sortEpochMonth, sortEpochDay, sortCorpusIndex
        case createdAt, updatedAt
    }

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        sourceFileName: String? = nil,
        category: DocumentCategory = .anthology,
        sortEpochYear: Int? = nil,
        sortEpochMonth: Int? = nil,
        sortEpochDay: Int? = nil,
        sortCorpusIndex: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.sourceFileName = sourceFileName
        self.category = category
        self.sortEpochYear = sortEpochYear
        self.sortEpochMonth = sortEpochMonth
        self.sortEpochDay = sortEpochDay
        self.sortCorpusIndex = sortCorpusIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        content = try c.decode(String.self, forKey: .content)
        sourceFileName = try c.decodeIfPresent(String.self, forKey: .sourceFileName)
        sortEpochYear = try c.decodeIfPresent(Int.self, forKey: .sortEpochYear)
        sortEpochMonth = try c.decodeIfPresent(Int.self, forKey: .sortEpochMonth)
        sortEpochDay = try c.decodeIfPresent(Int.self, forKey: .sortEpochDay)
        sortCorpusIndex = try c.decodeIfPresent(Int.self, forKey: .sortCorpusIndex)

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

    var contentNormalized: String {
        content.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isLikelyMarkdown: Bool {
        if let name = sourceFileName?.lowercased(), name.hasSuffix(".md") { return true }
        let s = content
        if s.contains("\n# ") || s.contains("\n## ") { return true }
        if s.hasPrefix("# ") || s.hasPrefix("## ") { return true }
        if s.contains("\n> ") || s.hasPrefix("> ") { return true }
        if s.contains("\n- ") || s.contains("\n* ") { return true }
        if s.contains("\n1. ") { return true }
        return false
    }

    /// Fills missing sort fields for poetry loaded before date/index extraction existed.
    mutating func backfillPoetrySortMetadataFromContentIfNeeded() {
        guard category == .poetry else { return }
        var body = content
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
