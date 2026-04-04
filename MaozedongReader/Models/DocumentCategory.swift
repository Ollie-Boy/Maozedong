import Foundation

enum DocumentCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case poetry
    case quote
    case article
    /// 对应文库中的著作汇编、选集等（如《毛泽东选集》卷次）
    case anthology

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .poetry: return "诗词"
        case .quote: return "语录"
        case .article: return "文章"
        case .anthology: return "选集"
        }
    }

    var systemImage: String {
        switch self {
        case .poetry: return "leaf.fill"
        case .quote: return "quote.bubble.fill"
        case .article: return "doc.text.fill"
        case .anthology: return "books.vertical.fill"
        }
    }
}
