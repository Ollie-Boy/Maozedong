import Foundation

enum DocumentCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case poetry
    case anthology

    var id: String { rawValue }

    /// Library section display title.
    var displayName: String {
        switch self {
        case .poetry: return "毛泽东诗词"
        case .anthology: return "毛泽东选集"
        }
    }
}
