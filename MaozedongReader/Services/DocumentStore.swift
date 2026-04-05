import Foundation

@MainActor
final class DocumentStore: ObservableObject {
    @Published var documents: [DocumentItem] = []
    @Published var readingPreferences: ReadingPreferences = .default {
        didSet {
            saveReadingPreferences()
        }
    }
    @Published private(set) var readerState: ReaderStateSnapshot = .empty
    @Published var errorMessage: String?

    private let fileManager = FileManager.default
    private let documentsMetadataFileName = "documents.json"
    private let readingPreferencesFileName = "reading_preferences.json"
    private let readerStateFileName = "reader_state.json"
    private let isPreviewMode: Bool

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var documentsMetadataURL: URL {
        documentsDirectory.appendingPathComponent(documentsMetadataFileName)
    }

    private var readingPreferencesURL: URL {
        documentsDirectory.appendingPathComponent(readingPreferencesFileName)
    }

    private var readerStateURL: URL {
        documentsDirectory.appendingPathComponent(readerStateFileName)
    }

    init(previewMode: Bool = false) {
        self.isPreviewMode = previewMode
        guard !previewMode else {
            documents = DocumentItem.previewItems
            readingPreferences = .default
            readerState = .empty
            return
        }

        loadAll()
        removeLegacySampleDocumentsIfNeeded()
        normalizeDocumentsAfterLoad()
        mergeBundledPoetryIfNeeded()
        mergeBundledAnthologyIfNeeded()
    }


    private static let legacySampleFileNames: Set<String> = [
        "沁园春·雪.md", "语录摘录.md", "文章示例.md",
        "sample.txt", "sample-quotes.md", "sample-article.md"
    ]

    private func removeLegacySampleDocumentsIfNeeded() {
        guard !isPreviewMode else { return }
        let before = documents.count
        documents.removeAll { doc in
            if doc.title.hasPrefix("示例：") { return true }
            if let n = doc.sourceFileName, Self.legacySampleFileNames.contains(n) { return true }
            return false
        }
        guard documents.count != before else { return }
        do {
            try saveDocuments()
        } catch {
            errorMessage = "清理旧示例文档失败：\(error.localizedDescription)"
        }
    }

    private static let bundledAnthologyVersionKey = "bundledAnthologyCorpusVersion"
    private static let bundledAnthologyVersion = "weiyinfu-src-bundled-v4-vol-split"

    private func mergeBundledAnthologyIfNeeded() {
        guard !isPreviewMode else { return }

        let anthologyDocs = BundledAnthologyImporter.loadDocuments()
        guard !anthologyDocs.isEmpty else { return }

        if UserDefaults.standard.string(forKey: Self.bundledAnthologyVersionKey) != Self.bundledAnthologyVersion {
            documents.removeAll { $0.sourceFileName?.hasPrefix(BundledAnthologyImporter.sourcePrefix) == true }
            documents.removeAll { $0.sourceFileName?.hasPrefix("remoteAnthology:") == true }
            documents.append(contentsOf: anthologyDocs)
            documents.sort(by: DocumentItem.displaySort)
            UserDefaults.standard.set(Self.bundledAnthologyVersion, forKey: Self.bundledAnthologyVersionKey)
            do {
                try saveDocuments()
            } catch {
                errorMessage = "写入内置选集失败：\(error.localizedDescription)"
            }
            return
        }

        let titles = Set(documents.map(\.title))
        var added = false
        for a in anthologyDocs where !titles.contains(a.title) {
            documents.append(a)
            added = true
        }
        if added {
            documents.sort(by: DocumentItem.displaySort)
            do {
                try saveDocuments()
            } catch {
                errorMessage = "合并内置选集失败：\(error.localizedDescription)"
            }
        }
    }

    private static let bundledPoetryVersionKey = "bundledPoetryCorpusVersion"
    private static let bundledPoetryVersion = "v7-poetry-no-zhengwen-heading"

    private func normalizeDocumentsAfterLoad() {
        guard !isPreviewMode else { return }
        var changed = false
        for i in documents.indices {
            var d = documents[i]
            let y0 = d.sortEpochYear
            let m0 = d.sortEpochMonth
            let d0 = d.sortEpochDay
            d.backfillPoetrySortMetadataFromContentIfNeeded()
            if d.sortEpochYear != y0 || d.sortEpochMonth != m0 || d.sortEpochDay != d0 {
                changed = true
            }
            documents[i] = d
        }
        let sorted = documents.sorted(by: DocumentItem.displaySort)
        if sorted.map(\.id) != documents.map(\.id) {
            documents = sorted
            changed = true
        }
        if changed {
            do {
                try saveDocuments()
            } catch {
                errorMessage = "整理书库排序失败：\(error.localizedDescription)"
            }
        }
    }

    /// Merges bundled poetry corpus (by title) so app updates add new works without wiping the library.
    private func mergeBundledPoetryIfNeeded() {
        guard !isPreviewMode else { return }

        let poetryDocs = BundledPoetryImporter.loadDocuments()
        guard !poetryDocs.isEmpty else { return }

        var changed = false

        if UserDefaults.standard.string(forKey: Self.bundledPoetryVersionKey) != Self.bundledPoetryVersion {
            documents.removeAll { $0.sourceFileName?.hasPrefix("bundled_poetry_") == true }
            documents.append(contentsOf: poetryDocs)
            UserDefaults.standard.set(Self.bundledPoetryVersion, forKey: Self.bundledPoetryVersionKey)
            changed = true
        }

        var titles = Set(documents.map(\.title))
        for p in poetryDocs where !titles.contains(p.title) {
            documents.append(p)
            titles.insert(p.title)
            changed = true
        }

        if changed {
            documents.sort(by: DocumentItem.displaySort)
            do {
                try saveDocuments()
            } catch {
                errorMessage = "合并内置诗词失败：\(error.localizedDescription)"
            }
        }
    }

    func importFiles(from urls: [URL]) throws {
        guard !isPreviewMode else { return }

        for url in urls {
            let shouldStopAccess = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let imported = try PlainTextFileImporter.parse(url: url)
                let category = PlainTextFileImporter.inferredCategory(
                    fileName: url.lastPathComponent,
                    content: imported.content
                )
                var item = DocumentItem(
                    title: imported.title,
                    content: imported.content,
                    sourceFileName: url.lastPathComponent,
                    category: category
                )
                item.backfillPoetrySortMetadataFromContentIfNeeded()
                documents.append(item)
            } catch {
                errorMessage = "导入 \(url.lastPathComponent) 失败：\(error.localizedDescription)"
            }
        }

        documents.sort(by: DocumentItem.displaySort)
        try saveDocuments()
    }

    func deleteDocuments(at offsets: IndexSet) {
        let removed = offsets.map { documents[$0] }
        documents.remove(atOffsets: offsets)
        var next = readerState
        for doc in removed {
            next.progressUTF16ByDocumentId.removeValue(forKey: doc.id)
            next.bookmarks.removeAll { $0.documentId == doc.id }
        }
        readerState = next
        do {
            try saveDocuments()
            saveReaderState()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    func deleteDocument(id: UUID) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        let doc = documents[idx]
        documents.remove(at: idx)
        var next = readerState
        next.progressUTF16ByDocumentId.removeValue(forKey: doc.id)
        next.bookmarks.removeAll { $0.documentId == doc.id }
        readerState = next
        do {
            try saveDocuments()
            saveReaderState()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    func updateCategory(documentId: UUID, category: DocumentCategory) {
        guard let idx = documents.firstIndex(where: { $0.id == documentId }) else { return }
        documents[idx].category = category
        documents[idx].updatedAt = Date()
        documents[idx].backfillPoetrySortMetadataFromContentIfNeeded()
        documents.sort(by: DocumentItem.displaySort)
        do {
            try saveDocuments()
        } catch {
            errorMessage = "保存分类失败：\(error.localizedDescription)"
        }
    }

    func setReadingProgress(documentId: UUID, utf16Offset: Int) {
        guard !isPreviewMode else { return }
        var next = readerState
        next.progressUTF16ByDocumentId[documentId] = max(0, utf16Offset)
        readerState = next
        saveReaderState()
    }

    func progressUTF16Offset(for documentId: UUID) -> Int? {
        readerState.progressUTF16ByDocumentId[documentId]
    }

    func addBookmark(documentId: UUID, utf16Offset: Int, label: String) {
        guard !isPreviewMode else { return }
        let entry = BookmarkEntry(documentId: documentId, utf16Offset: max(0, utf16Offset), label: label)
        var next = readerState
        next.bookmarks.insert(entry, at: 0)
        readerState = next
        saveReaderState()
    }

    func removeBookmarks(ids: [UUID]) {
        guard !isPreviewMode else { return }
        let idSet = Set(ids)
        var next = readerState
        next.bookmarks.removeAll { idSet.contains($0.id) }
        readerState = next
        saveReaderState()
    }

    func bookmarks(for documentId: UUID) -> [BookmarkEntry] {
        readerState.bookmarks.filter { $0.documentId == documentId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func saveReadingPreferences() {
        guard !isPreviewMode else { return }

        do {
            let data = try JSONEncoder().encode(readingPreferences)
            try data.write(to: readingPreferencesURL, options: .atomic)
        } catch {
            errorMessage = "保存阅读设置失败：\(error.localizedDescription)"
        }
    }

    private func saveReaderState() {
        guard !isPreviewMode else { return }
        do {
            let data = try JSONEncoder().encode(readerState)
            try data.write(to: readerStateURL, options: .atomic)
        } catch {
            errorMessage = "保存阅读进度失败：\(error.localizedDescription)"
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func loadAll() {
        loadDocuments()
        loadReadingPreferences()
        loadReaderState()
    }

    private func loadDocuments() {
        guard fileManager.fileExists(atPath: documentsMetadataURL.path) else {
            documents = []
            return
        }
        do {
            let data = try Data(contentsOf: documentsMetadataURL)
            documents = try JSONDecoder().decode([DocumentItem].self, from: data)
        } catch {
            documents = []
            errorMessage = "读取文档列表失败：\(error.localizedDescription)"
        }
    }

    private func loadReadingPreferences() {
        guard fileManager.fileExists(atPath: readingPreferencesURL.path) else {
            readingPreferences = .default
            return
        }
        do {
            let data = try Data(contentsOf: readingPreferencesURL)
            readingPreferences = try JSONDecoder().decode(ReadingPreferences.self, from: data)
        } catch {
            readingPreferences = .default
            errorMessage = "读取阅读设置失败：\(error.localizedDescription)"
        }
    }

    private func loadReaderState() {
        guard fileManager.fileExists(atPath: readerStateURL.path) else {
            readerState = .empty
            return
        }
        do {
            let data = try Data(contentsOf: readerStateURL)
            readerState = try JSONDecoder().decode(ReaderStateSnapshot.self, from: data)
        } catch {
            readerState = .empty
            errorMessage = "读取阅读进度失败：\(error.localizedDescription)"
        }
    }

    private func saveDocuments() throws {
        let data = try JSONEncoder().encode(documents)
        try data.write(to: documentsMetadataURL, options: .atomic)
    }

}
