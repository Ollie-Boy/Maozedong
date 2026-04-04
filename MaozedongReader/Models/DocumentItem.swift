import Foundation

struct DocumentItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var sourceFileName: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        sourceFileName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.sourceFileName = sourceFileName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var contentNormalized: String {
        content.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
            sourceFileName: "sample.txt"
        )
    ]
}
