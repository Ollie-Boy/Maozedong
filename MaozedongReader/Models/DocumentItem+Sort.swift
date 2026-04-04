import Foundation

extension DocumentItem {
    /// Stable order for list UI: poetry by time, then corpus index; anthology by title.
    static func displaySort(_ a: DocumentItem, _ b: DocumentItem) -> Bool {
        if a.category != b.category {
            return a.category.sortOrder < b.category.sortOrder
        }
        switch a.category {
        case .poetry:
            let ay = a.sortEpochYear ?? 10_000
            let by = b.sortEpochYear ?? 10_000
            if ay != by { return ay < by }
            let am = a.sortEpochMonth ?? 0
            let bm = b.sortEpochMonth ?? 0
            if am != bm { return am < bm }
            let ad = a.sortEpochDay ?? 0
            let bd = b.sortEpochDay ?? 0
            if ad != bd { return ad < bd }
            let ai = a.sortCorpusIndex ?? 10_000
            let bi = b.sortCorpusIndex ?? 10_000
            if ai != bi { return ai < bi }
            return a.title < b.title
        case .anthology:
            let ar = a.sourceFileName?.hasPrefix(RemoteAnthologySync.sourcePrefix) == true
            let br = b.sourceFileName?.hasPrefix(RemoteAnthologySync.sourcePrefix) == true
            if ar, br {
                let ai = a.sortCorpusIndex ?? 99_999
                let bi = b.sortCorpusIndex ?? 99_999
                if ai != bi { return ai < bi }
            }
            return a.title.localizedStandardCompare(b.title) == .orderedAscending
        }
    }
}

private extension DocumentCategory {
    var sortOrder: Int {
        switch self {
        case .poetry: return 0
        case .anthology: return 1
        }
    }
}
