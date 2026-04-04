import Foundation

struct DocumentItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var sourceFileName: String?
    var category: DocumentCategory
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, content, sourceFileName, category, createdAt, updatedAt
    }

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        sourceFileName: String? = nil,
        category: DocumentCategory = .article,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.sourceFileName = sourceFileName
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        content = try c.decode(String.self, forKey: .content)
        sourceFileName = try c.decodeIfPresent(String.self, forKey: .sourceFileName)
        category = try c.decodeIfPresent(DocumentCategory.self, forKey: .category) ?? .article
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
}

extension DocumentItem {
    static let previewItems: [DocumentItem] = [
        DocumentItem(
            title: "示例：沁园春·雪",
            content: """
            北国风光，千里冰封，万里雪飘。
            望长城内外，惟余莽莽；
            大河上下，顿失滔滔。
            山舞银蛇，原驰蜡象，欲与天公试比高。
            须晴日，看红装素裹，分外妖娆。
            """,
            sourceFileName: "sample.txt",
            category: .poetry
        )
    ]
}
