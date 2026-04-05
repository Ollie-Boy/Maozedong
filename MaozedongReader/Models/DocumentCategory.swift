import Foundation

enum DocumentCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case poetry
    case anthology

    var id: String { rawValue }

    /// Library section titles (no SF Symbol in headers — text only).
    var displayName: String {
        switch self {
        case .poetry: return "毛泽东诗词"
        case .anthology: return "毛泽东选集"
        }
    }
}
