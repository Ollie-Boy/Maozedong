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
    /// 《毛泽东选集》式分卷/分期标题（来自 `AnthologyTOC.md`）；无 `##` 小节时与卷名相同。
    var anthologySectionTitle: String?
    /// 卷级标题（`#` 行），书库一级分组用。
    var anthologyMajorTitle: String?
    var anthologyMajorOrder: Int?
    var anthologySubOrder: Int?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, content, sourceFileName, category
        case sortEpochYear, sortEpochMonth, sortEpochDay, sortCorpusIndex
        case anthologySectionTitle, anthologyMajorTitle, anthologyMajorOrder, anthologySubOrder
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
        anthologySectionTitle: String? = nil,
        anthologyMajorTitle: String? = nil,
        anthologyMajorOrder: Int? = nil,
        anthologySubOrder: Int? = nil,
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
        self.anthologySectionTitle = anthologySectionTitle
        self.anthologyMajorTitle = anthologyMajorTitle
        self.anthologyMajorOrder = anthologyMajorOrder
        self.anthologySubOrder = anthologySubOrder
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
        anthologySectionTitle = try c.decodeIfPresent(String.self, forKey: .anthologySectionTitle)
        anthologyMajorTitle = try c.decodeIfPresent(String.self, forKey: .anthologyMajorTitle)
        anthologyMajorOrder = try c.decodeIfPresent(Int.self, forKey: .anthologyMajorOrder)
        anthologySubOrder = try c.decodeIfPresent(Int.self, forKey: .anthologySubOrder)

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

    /// Pager groups bundled anthology articles by volume/period from the TOC.
    var anthologyScrollGroupKey: String {
        guard category == .anthology,
              let m = anthologyMajorOrder,
              let s = anthologySubOrder else {
            return "anthology:\(id.uuidString)"
        }
        return "bundledAnthology:\(m):\(s)"
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
