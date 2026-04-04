import Foundation

enum DocumentCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case poetry
    case quote
    case article

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .poetry: return "诗词"
        case .quote: return "语录"
        case .article: return "文章"
        }
    }

    var systemImage: String {
        switch self {
        case .poetry: return "leaf.fill"
        case .quote: return "quote.bubble.fill"
        case .article: return "doc.text.fill"
        }
    }
}
