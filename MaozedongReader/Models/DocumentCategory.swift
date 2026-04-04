import Foundation

enum DocumentCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case poetry
    case anthology

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .poetry: return "诗词"
        case .anthology: return "选集"
        }
    }

    var systemImage: String {
        switch self {
        case .poetry: return "leaf.fill"
        case .anthology: return "books.vertical.fill"
        }
    }
}
