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
        seedIfNeeded()
        mergeBundledPoetryIfNeeded()
    }

    private static let bundledPoetryMergeKey = "didMergeBundledPoetryCorpus_v1"

    /// Merges bundled poetry corpus (by title) so app updates add new works without wiping the library.
    private func mergeBundledPoetryIfNeeded() {
        guard !isPreviewMode else { return }

        let poetryDocs = BundledPoetryImporter.loadDocuments()
        guard !poetryDocs.isEmpty else { return }

        if UserDefaults.standard.bool(forKey: Self.bundledPoetryMergeKey) {
            let existingTitles = Set(documents.map(\.title))
            var added = false
            for p in poetryDocs where !existingTitles.contains(p.title) {
                documents.append(p)
                added = true
            }
            if added {
                do {
                    try saveDocuments()
                } catch {
                    errorMessage = "合并内置诗词失败：\(error.localizedDescription)"
                }
            }
            return
        }

        let bundled = BundledSampleImporter.loadDocuments()
        let hasSampleOnly = documents.count <= 4
            && documents.allSatisfy { doc in
                doc.sourceFileName?.hasSuffix(".md") == true || doc.sourceFileName == "sample.txt"
            }

        if documents.isEmpty || hasSampleOnly {
            var merged = poetryDocs
            for s in bundled where !merged.contains(where: { $0.title == s.title }) {
                merged.append(s)
            }
            documents = merged.sorted { $0.title < $1.title }
            UserDefaults.standard.set(true, forKey: Self.bundledPoetryMergeKey)
            do {
                try saveDocuments()
            } catch {
                errorMessage = "写入内置诗词失败：\(error.localizedDescription)"
            }
            return
        }

        let existingTitles = Set(documents.map(\.title))
        var added = false
        for p in poetryDocs where !existingTitles.contains(p.title) {
            documents.append(p)
            added = true
        }
        UserDefaults.standard.set(true, forKey: Self.bundledPoetryMergeKey)
        if added {
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
                let item = DocumentItem(
                    title: imported.title,
                    content: imported.content,
                    sourceFileName: url.lastPathComponent,
                    category: category
                )
                documents.insert(item, at: 0)
            } catch {
                errorMessage = "导入 \(url.lastPathComponent) 失败：\(error.localizedDescription)"
            }
        }

        try saveDocuments()
    }

    func deleteDocuments(at offsets: IndexSet) {
        let removed = offsets.map { documents[$0] }
        documents.remove(atOffsets: offsets)
        for doc in removed {
            readerState.progressUTF16ByDocumentId.removeValue(forKey: doc.id)
            readerState.bookmarks.removeAll { $0.documentId == doc.id }
        }
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
        readerState.progressUTF16ByDocumentId.removeValue(forKey: doc.id)
        readerState.bookmarks.removeAll { $0.documentId == doc.id }
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
        do {
            try saveDocuments()
        } catch {
            errorMessage = "保存分类失败：\(error.localizedDescription)"
        }
    }

    func setReadingProgress(documentId: UUID, utf16Offset: Int) {
        guard !isPreviewMode else { return }
        readerState.progressUTF16ByDocumentId[documentId] = max(0, utf16Offset)
        saveReaderState()
    }

    func progressUTF16Offset(for documentId: UUID) -> Int? {
        readerState.progressUTF16ByDocumentId[documentId]
    }

    func addBookmark(documentId: UUID, utf16Offset: Int, label: String) {
        guard !isPreviewMode else { return }
        let entry = BookmarkEntry(documentId: documentId, utf16Offset: max(0, utf16Offset), label: label)
        readerState.bookmarks.insert(entry, at: 0)
        saveReaderState()
    }

    func removeBookmarks(ids: [UUID]) {
        guard !isPreviewMode else { return }
        let idSet = Set(ids)
        readerState.bookmarks.removeAll { idSet.contains($0.id) }
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

    private func seedIfNeeded() {
        guard !isPreviewMode else { return }
        guard documents.isEmpty else { return }

        let bundled = BundledSampleImporter.loadDocuments()
        if !bundled.isEmpty {
            do {
                documents = bundled
                try saveDocuments()
            } catch {
                errorMessage = "写入示例文档失败：\(error.localizedDescription)"
            }
            return
        }

        let poetry = DocumentItem(
            title: "示例：沁园春·雪",
            content: """
            北国风光，千里冰封，万里雪飘。
            望长城内外，惟余莽莽；
            大河上下，顿失滔滔。
            山舞银蛇，原驰蜡象，欲与天公试比高。
            须晴日，看红装素裹，分外妖娆。

            江山如此多娇，引无数英雄竞折腰。
            惜秦皇汉武，略输文采；
            唐宗宋祖，稍逊风骚。
            一代天骄，成吉思汗，只识弯弓射大雕。
            俱往矣，数风流人物，还看今朝。
            """,
            sourceFileName: "sample.txt",
            category: .poetry
        )

        let quoteMD = """
        # 语录摘录

        > 没有调查，没有发言权。

        > 星星之火，可以燎原。

        以上条目可作为**语录**类文档的排版示例；行内强调可用 `**粗体**` 与 `` `代码` ``。
        """

        let quote = DocumentItem(
            title: "示例：语录（Markdown）",
            content: quoteMD,
            sourceFileName: "sample-quotes.md",
            category: .quote
        )

        let articleMD = """
        # 文章结构示例

        这是一篇演示 **Markdown** 渲染与目录的短文。

        ## 列表与要点

        - 无序列表第一项
        - 第二项，可含 `行内代码`

        1. 有序列表一
        2. 有序列表二

        ## 引用

        > 引用块用于摘录或强调整段文字。
        > 可以多行连续书写。

        ---

        ### 小结

        从右上角可打开**目录**、**搜索**与**书签**。导入 `SampleContent` 目录下的 `.md` 可体验完整排版。
        """

        let article = DocumentItem(
            title: "示例：文章（Markdown）",
            content: articleMD,
            sourceFileName: "sample-article.md",
            category: .article
        )

        do {
            documents = [article, quote, poetry]
            try saveDocuments()
        } catch {
            errorMessage = "写入示例文档失败：\(error.localizedDescription)"
        }
    }
}
