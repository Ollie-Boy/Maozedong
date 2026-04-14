import Foundation

@MainActor
final class DocumentStore: ObservableObject {
    @Published var documents: [DocumentItem] = []
    @Published var libraryFolders: [LibraryFolder] = []
    @Published var readingPreferences: ReadingPreferences = .default {
        didSet {
            if readingPreferencesPersistenceDepth == 0 {
                scheduleReadingPreferencesDiskWrite()
            }
        }
    }
    @Published private(set) var readerState: ReaderStateSnapshot = .empty
    @Published var errorMessage: String?
    /// Set when `librarySearchIndex` has finished building for current `documents` (UI may show faster path).
    @Published private(set) var librarySearchIndexReady = false

    private var librarySearchIndex: LibrarySearchIndex?
    private var librarySearchIndexTask: Task<Void, Never>?

    private var readerStateDiskTask: Task<Void, Never>?
    private var lastOpenedDocumentTask: Task<Void, Never>?
    private var pendingLastOpenedDocumentId: UUID?
    private var readingPreferencesDiskTask: Task<Void, Never>?
    /// Skip persisting when assigning preferences loaded from disk (avoid rewrite-on-launch).
    private var readingPreferencesPersistenceDepth = 0

    private let fileManager = FileManager.default
    private let documentsMetadataFileName = "documents.json"
    private let libraryFoldersFileName = "library_folders.json"
    private let readingPreferencesFileName = "reading_preferences.json"
    private let readerStateFileName = "reader_state.json"
    private let isPreviewMode: Bool

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var documentsMetadataURL: URL {
        documentsDirectory.appendingPathComponent(documentsMetadataFileName)
    }

    private var libraryFoldersURL: URL {
        documentsDirectory.appendingPathComponent(libraryFoldersFileName)
    }

    private var articleBodiesDirectoryURL: URL {
        documentsDirectory.appendingPathComponent("ArticleBodies", isDirectory: true)
    }

    /// Bodies at or above this UTF-8 size are stored in `ArticleBodies/{uuid}.txt`; JSON keeps metadata + preview only.
    private static let articleBodyExternalThreshold = 40 * 1024
    /// Kept moderate: hundreds of externalized articles × preview still sits in `documents.json` in RAM.
    private static let articleBodyPreviewMaxChars = 24_000

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
            libraryFolders = []
            withoutReadingPreferencesPersistence {
                readingPreferences = .default
            }
            readerState = .empty
            return
        }

        loadAll()
        removeLegacySampleDocumentsIfNeeded()
        syncDocumentLibraryFolderSortKeysFromFoldersIfNeeded()
        normalizeDocumentsAfterLoad()
        mergeBundledPoetryIfNeeded()
        mergeBundledAnthologyIfNeeded()
        scheduleRebuildLibrarySearchIndex()
    }

    /// Documents to scan for `query`: full list when index is building or query is one character; narrowed set when index can prune.
    func librarySearchDocumentsToScan(for query: String) -> [DocumentItem] {
        guard let index = librarySearchIndex else { return documents }
        guard let idSet = index.candidateIds(for: query) else { return documents }
        if idSet.isEmpty { return [] }
        return documents.filter { idSet.contains($0.id) }
    }

    private func scheduleRebuildLibrarySearchIndex() {
        librarySearchIndexTask?.cancel()
        librarySearchIndexReady = false
        librarySearchIndex = nil
        let rows: [(UUID, String, String)] = documents.map { doc in
            let prefix = String(doc.textForLibrarySearch.prefix(LibrarySearchIndex.indexPreviewCharCount))
            return (doc.id, doc.title, prefix)
        }
        librarySearchIndexTask = Task { @MainActor in
            let built = await Task.detached {
                LibrarySearchIndex.build(rows: rows.map { (id: $0.0, title: $0.1, preview: $0.2) })
            }.value
            guard !Task.isCancelled else { return }
            librarySearchIndex = built
            librarySearchIndexReady = true
            librarySearchIndexTask = nil
        }
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
    private static let bundledAnthologyVersion = "weiyinfu-src-bundled-v6-toc-filter"

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
    private static let bundledPoetryVersion = "v12-poetry-year-suffix-dates"

    private func normalizeDocumentsAfterLoad() {
        guard !isPreviewMode else { return }
        var changed = false
        for i in documents.indices {
            var d = documents[i]
            let y0 = d.sortEpochYear
            let m0 = d.sortEpochMonth
            let d0 = d.sortEpochDay
            let resolved = (d.category == .poetry && d.content.isEmpty && d.contentExternalized) ? resolvedBody(for: d) : nil
            d.backfillPoetrySortMetadataFromContentIfNeeded(resolvedBody: resolved)
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

    func importFiles(from urls: [URL], forcedCategory: DocumentCategory? = nil, libraryFolderId: UUID? = nil) throws {
        guard !isPreviewMode else { return }

        let folderSortKey: Int
        if let libraryFolderId,
           let folder = libraryFolders.first(where: { $0.id == libraryFolderId }) {
            folderSortKey = folder.sortOrder
        } else {
            folderSortKey = 0
        }

        for url in urls {
            let shouldStopAccess = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let imported = try PlainTextFileImporter.parse(url: url)
                let category = forcedCategory ?? PlainTextFileImporter.inferredCategory(
                    fileName: url.lastPathComponent,
                    content: imported.content
                )
                var item = DocumentItem(
                    title: imported.title,
                    content: imported.content,
                    sourceFileName: url.lastPathComponent,
                    category: category,
                    libraryFolderId: libraryFolderId,
                    libraryFolderSortKey: folderSortKey
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
        for doc in removed where doc.contentExternalized {
            let url = articleBodiesDirectoryURL.appendingPathComponent("\(doc.id.uuidString).txt")
            try? fileManager.removeItem(at: url)
        }
        documents.remove(atOffsets: offsets)
        var next = readerState
        for doc in removed {
            next.progressUTF16ByDocumentId.removeValue(forKey: doc.id)
            if next.lastOpenedDocumentId == doc.id {
                next.lastOpenedDocumentId = nil
                next.lastOpenedAt = nil
            }
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
        if doc.contentExternalized {
            let url = articleBodiesDirectoryURL.appendingPathComponent("\(id.uuidString).txt")
            try? fileManager.removeItem(at: url)
        }
        documents.remove(at: idx)
        var next = readerState
        next.progressUTF16ByDocumentId.removeValue(forKey: doc.id)
        if next.lastOpenedDocumentId == doc.id {
            next.lastOpenedDocumentId = nil
            next.lastOpenedAt = nil
        }
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
        if documents[idx].category != category {
            documents[idx].libraryFolderId = nil
            documents[idx].libraryFolderSortKey = 0
        }
        documents[idx].category = category
        documents[idx].updatedAt = Date()
        let resolved = (documents[idx].category == .poetry && documents[idx].content.isEmpty && documents[idx].contentExternalized)
            ? resolvedBody(for: documents[idx])
            : nil
        documents[idx].backfillPoetrySortMetadataFromContentIfNeeded(resolvedBody: resolved)
        documents.sort(by: DocumentItem.displaySort)
        do {
            try saveDocuments()
        } catch {
            errorMessage = "保存分类失败：\(error.localizedDescription)"
        }
    }

    func setReadingProgress(documentId: UUID, utf16Offset: Int) {
        guard !isPreviewMode else { return }
        let u = max(0, utf16Offset)
        if readerState.progressUTF16ByDocumentId[documentId] == u { return }
        var next = readerState
        next.progressUTF16ByDocumentId[documentId] = u
        readerState = next
        scheduleReaderStateDiskWrite()
    }

    func recordLastOpenedDocument(documentId: UUID) {
        guard !isPreviewMode else { return }
        var next = readerState
        next.lastOpenedDocumentId = documentId
        next.lastOpenedAt = Date()
        readerState = next
        scheduleReaderStateDiskWrite()
    }

    /// Batches rapid horizontal pager changes so `readerState` does not republish on every scroll tick (high CPU / Energy).
    func scheduleRecordLastOpenedDocument(documentId: UUID) {
        guard !isPreviewMode else { return }
        pendingLastOpenedDocumentId = documentId
        lastOpenedDocumentTask?.cancel()
        lastOpenedDocumentTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            guard let id = pendingLastOpenedDocumentId else { return }
            recordLastOpenedDocument(documentId: id)
            pendingLastOpenedDocumentId = nil
        }
    }

    /// Call when leaving the reader stack so the last swiped article is recorded immediately.
    func flushLastOpenedDocumentSchedule() {
        lastOpenedDocumentTask?.cancel()
        lastOpenedDocumentTask = nil
        if let id = pendingLastOpenedDocumentId {
            recordLastOpenedDocument(documentId: id)
            pendingLastOpenedDocumentId = nil
        }
    }

    var continueReadingDocument: DocumentItem? {
        guard let id = readerState.lastOpenedDocumentId else { return nil }
        return documents.first { $0.id == id }
    }

    /// Inline externalized bodies so backups restore on a fresh install without `ArticleBodies/`.
    private func documentForBackup(_ d: DocumentItem) -> DocumentItem {
        var x = d
        guard x.contentExternalized else { return x }
        guard let body = resolvedBody(for: d) else { return x }
        x.content = body
        x.contentExternalized = false
        x.contentPreview = nil
        return x
    }

    /// Exports `documents.json` + `reader_state.json` + `reading_preferences.json` into one JSON file (offline backup).
    func exportBackupData() throws -> Data {
        let payload = BackupPayload(
            documents: documents.map(documentForBackup),
            libraryFolders: libraryFolders,
            readerState: readerState,
            readingPreferences: readingPreferences,
            exportedAt: Date()
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(payload)
    }

    /// Replaces library + reader state + preferences from a backup file.
    func importBackup(data: Data) throws {
        guard !isPreviewMode else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let payload = try dec.decode(BackupPayload.self, from: data)
        documents = payload.documents.sorted(by: DocumentItem.displaySort)
        libraryFolders = payload.libraryFolders
        try? saveLibraryFolders()
        syncDocumentLibraryFolderSortKeysFromFoldersIfNeeded()
        readerState = payload.readerState
        withoutReadingPreferencesPersistence {
            readingPreferences = payload.readingPreferences
        }
        try saveDocuments()
        saveReaderState()
        persistReadingPreferencesToDiskNow()
    }

    func progressUTF16Offset(for documentId: UUID) -> Int? {
        readerState.progressUTF16ByDocumentId[documentId]
    }

    /// Call when closing a settings UI so the last slider tick is not still pending in the debounce window.
    func flushReadingPreferencesToDisk() {
        persistReadingPreferencesToDiskNow()
    }

    private func withoutReadingPreferencesPersistence(_ work: () -> Void) {
        readingPreferencesPersistenceDepth += 1
        work()
        readingPreferencesPersistenceDepth -= 1
    }

    private func scheduleReadingPreferencesDiskWrite() {
        guard !isPreviewMode else { return }
        readingPreferencesDiskTask?.cancel()
        readingPreferencesDiskTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }
            persistReadingPreferencesToDiskNow()
        }
    }

    private func persistReadingPreferencesToDiskNow() {
        readingPreferencesDiskTask?.cancel()
        readingPreferencesDiskTask = nil
        guard !isPreviewMode else { return }
        do {
            let data = try JSONEncoder().encode(readingPreferences)
            try data.write(to: readingPreferencesURL, options: .atomic)
        } catch {
            errorMessage = "保存阅读设置失败：\(error.localizedDescription)"
        }
    }

    /// Batches rapid progress / “last opened” updates so scrolling and pager switches do not sync JSON on every event.
    private func scheduleReaderStateDiskWrite() {
        guard !isPreviewMode else { return }
        readerStateDiskTask?.cancel()
        readerStateDiskTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            saveReaderState()
        }
    }

    private func saveReaderState() {
        readerStateDiskTask?.cancel()
        readerStateDiskTask = nil
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
        loadLibraryFolders()
        loadReadingPreferences()
        loadReaderState()
    }

    private func loadLibraryFolders() {
        guard fileManager.fileExists(atPath: libraryFoldersURL.path) else {
            libraryFolders = []
            return
        }
        do {
            let data = try Data(contentsOf: libraryFoldersURL)
            libraryFolders = try JSONDecoder().decode([LibraryFolder].self, from: data)
        } catch {
            libraryFolders = []
            errorMessage = "读取书库目录失败：\(error.localizedDescription)"
        }
    }

    private func saveLibraryFolders() throws {
        let data = try JSONEncoder().encode(libraryFolders)
        try data.write(to: libraryFoldersURL, options: .atomic)
    }

    /// Keeps `libraryFolderSortKey` in sync with folder list (and drops stale folder ids).
    private func syncDocumentLibraryFolderSortKeysFromFoldersIfNeeded() {
        guard !isPreviewMode else { return }
        var changed = false
        for i in documents.indices {
            var d = documents[i]
            if let fid = d.libraryFolderId {
                guard let folder = libraryFolders.first(where: { $0.id == fid }),
                      folder.category == d.category else {
                    d.libraryFolderId = nil
                    d.libraryFolderSortKey = 0
                    changed = true
                    documents[i] = d
                    continue
                }
                if d.libraryFolderSortKey != folder.sortOrder {
                    d.libraryFolderSortKey = folder.sortOrder
                    changed = true
                }
            } else if d.libraryFolderSortKey != 0 {
                d.libraryFolderSortKey = 0
                changed = true
            }
            documents[i] = d
        }
        guard changed else { return }
        let sorted = documents.sorted(by: DocumentItem.displaySort)
        if sorted.map(\.id) != documents.map(\.id) {
            documents = sorted
        }
        do {
            try saveDocuments()
        } catch {
            errorMessage = "同步书库目录排序失败：\(error.localizedDescription)"
        }
    }

    func addLibraryFolder(category: DocumentCategory, title: String) {
        guard !isPreviewMode else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let nextOrder = (libraryFolders.filter { $0.category == category }.map(\.sortOrder).max() ?? -1) + 1
        libraryFolders.append(LibraryFolder(category: category, title: t, sortOrder: nextOrder))
        do {
            try saveLibraryFolders()
        } catch {
            errorMessage = "保存书库目录失败：\(error.localizedDescription)"
        }
    }

    func renameLibraryFolder(id: UUID, newTitle: String) {
        guard !isPreviewMode else { return }
        let t = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        guard let idx = libraryFolders.firstIndex(where: { $0.id == id }) else { return }
        libraryFolders[idx].title = t
        do {
            try saveLibraryFolders()
        } catch {
            errorMessage = "重命名目录失败：\(error.localizedDescription)"
        }
    }

    func deleteLibraryFolder(id: UUID) {
        guard !isPreviewMode else { return }
        libraryFolders.removeAll { $0.id == id }
        for i in documents.indices where documents[i].libraryFolderId == id {
            documents[i].libraryFolderId = nil
            documents[i].libraryFolderSortKey = 0
            documents[i].updatedAt = Date()
        }
        documents.sort(by: DocumentItem.displaySort)
        do {
            try saveLibraryFolders()
            try saveDocuments()
        } catch {
            errorMessage = "删除目录失败：\(error.localizedDescription)"
        }
        scheduleRebuildLibrarySearchIndex()
    }

    func assignDocuments(documentIds: [UUID], toFolderId folderId: UUID?) {
        guard !isPreviewMode else { return }
        let sortKey: Int
        if let folderId,
           let folder = libraryFolders.first(where: { $0.id == folderId }) {
            sortKey = folder.sortOrder
        } else {
            sortKey = 0
        }
        var touched = false
        for id in documentIds {
            guard let idx = documents.firstIndex(where: { $0.id == id }) else { continue }
            if let folderId {
                guard let folder = libraryFolders.first(where: { $0.id == folderId }),
                      folder.category == documents[idx].category else { continue }
            }
            documents[idx].libraryFolderId = folderId
            documents[idx].libraryFolderSortKey = folderId == nil ? 0 : sortKey
            documents[idx].updatedAt = Date()
            touched = true
        }
        guard touched else { return }
        documents.sort(by: DocumentItem.displaySort)
        do {
            try saveDocuments()
        } catch {
            errorMessage = "移动篇目失败：\(error.localizedDescription)"
        }
        scheduleRebuildLibrarySearchIndex()
    }

    private func loadDocuments() {
        guard fileManager.fileExists(atPath: documentsMetadataURL.path) else {
            documents = []
            return
        }
        do {
            let data = try Data(contentsOf: documentsMetadataURL)
            documents = try JSONDecoder().decode([DocumentItem].self, from: data)
            try migrateInMemoryLargeBodiesToExternalFiles()
            trimOversizedContentPreviewsIfNeeded()
        } catch {
            documents = []
            errorMessage = "读取文档列表失败：\(error.localizedDescription)"
        }
    }

    /// Full article text for reading / export. Inline `content` or UTF-8 file in `ArticleBodies/`.
    func resolvedBody(for item: DocumentItem) -> String? {
        if !item.contentExternalized {
            return item.content
        }
        let url = articleBodiesDirectoryURL.appendingPathComponent("\(item.id.uuidString).txt")
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Read externalized body off the main actor (same path as `resolvedBody`).
    nonisolated static func readExternalizedBodyInBackground(id: UUID) -> String {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ArticleBodies", isDirectory: true)
        let url = dir.appendingPathComponent("\(id.uuidString).txt")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private func trimOversizedContentPreviewsIfNeeded() {
        var changed = false
        for i in documents.indices {
            guard documents[i].contentExternalized,
                  let p = documents[i].contentPreview,
                  p.count > Self.articleBodyPreviewMaxChars else { continue }
            documents[i].contentPreview = String(p.prefix(Self.articleBodyPreviewMaxChars))
            changed = true
        }
        if changed {
            try? saveDocuments()
        }
    }

    private func migrateInMemoryLargeBodiesToExternalFiles() throws {
        try fileManager.createDirectory(at: articleBodiesDirectoryURL, withIntermediateDirectories: true)
        var changed = false
        var next: [DocumentItem] = []
        next.reserveCapacity(documents.count)
        for var d in documents {
            guard !d.contentExternalized else {
                next.append(d)
                continue
            }
            let byteCount = d.content.lengthOfBytes(using: .utf8)
            guard byteCount >= Self.articleBodyExternalThreshold else {
                next.append(d)
                continue
            }
            let url = articleBodiesDirectoryURL.appendingPathComponent("\(d.id.uuidString).txt")
            try d.content.write(to: url, atomically: true, encoding: .utf8)
            d.contentPreview = String(d.content.prefix(Self.articleBodyPreviewMaxChars))
            d.content = ""
            d.contentExternalized = true
            changed = true
            next.append(d)
        }
        documents = next
        if changed {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: documentsMetadataURL, options: .atomic)
        }
    }

    private func prepareDocumentForPersistence(_ d: inout DocumentItem) throws {
        if d.contentExternalized {
            let url = articleBodiesDirectoryURL.appendingPathComponent("\(d.id.uuidString).txt")
            if !d.content.isEmpty {
                try fileManager.createDirectory(at: articleBodiesDirectoryURL, withIntermediateDirectories: true)
                try d.content.write(to: url, atomically: true, encoding: .utf8)
                d.content = ""
            }
            if d.contentPreview == nil, fileManager.fileExists(atPath: url.path),
               let full = try? String(contentsOf: url, encoding: .utf8) {
                d.contentPreview = String(full.prefix(Self.articleBodyPreviewMaxChars))
            }
            return
        }
        let byteCount = d.content.lengthOfBytes(using: .utf8)
        guard byteCount >= Self.articleBodyExternalThreshold else { return }
        try fileManager.createDirectory(at: articleBodiesDirectoryURL, withIntermediateDirectories: true)
        let url = articleBodiesDirectoryURL.appendingPathComponent("\(d.id.uuidString).txt")
        try d.content.write(to: url, atomically: true, encoding: .utf8)
        d.contentPreview = String(d.content.prefix(Self.articleBodyPreviewMaxChars))
        d.content = ""
        d.contentExternalized = true
    }

    private func loadReadingPreferences() {
        guard fileManager.fileExists(atPath: readingPreferencesURL.path) else {
            withoutReadingPreferencesPersistence {
                readingPreferences = .default
            }
            return
        }
        do {
            let data = try Data(contentsOf: readingPreferencesURL)
            let decoded = try JSONDecoder().decode(ReadingPreferences.self, from: data)
            withoutReadingPreferencesPersistence {
                readingPreferences = decoded
            }
        } catch {
            withoutReadingPreferencesPersistence {
                readingPreferences = .default
            }
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
        try fileManager.createDirectory(at: articleBodiesDirectoryURL, withIntermediateDirectories: true)
        var next: [DocumentItem] = []
        next.reserveCapacity(documents.count)
        for var d in documents {
            try prepareDocumentForPersistence(&d)
            next.append(d)
        }
        documents = next
        let data = try JSONEncoder().encode(documents)
        try data.write(to: documentsMetadataURL, options: .atomic)
        scheduleRebuildLibrarySearchIndex()
    }
}

private struct BackupPayload: Codable {
    var documents: [DocumentItem]
    var libraryFolders: [LibraryFolder]
    var readerState: ReaderStateSnapshot
    var readingPreferences: ReadingPreferences
    var exportedAt: Date

    init(
        documents: [DocumentItem],
        libraryFolders: [LibraryFolder],
        readerState: ReaderStateSnapshot,
        readingPreferences: ReadingPreferences,
        exportedAt: Date
    ) {
        self.documents = documents
        self.libraryFolders = libraryFolders
        self.readerState = readerState
        self.readingPreferences = readingPreferences
        self.exportedAt = exportedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        documents = try c.decode([DocumentItem].self, forKey: .documents)
        libraryFolders = try c.decodeIfPresent([LibraryFolder].self, forKey: .libraryFolders) ?? []
        readerState = try c.decode(ReaderStateSnapshot.self, forKey: .readerState)
        readingPreferences = try c.decode(ReadingPreferences.self, forKey: .readingPreferences)
        exportedAt = try c.decode(Date.self, forKey: .exportedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case documents, libraryFolders, readerState, readingPreferences, exportedAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(documents, forKey: .documents)
        try c.encode(libraryFolders, forKey: .libraryFolders)
        try c.encode(readerState, forKey: .readerState)
        try c.encode(readingPreferences, forKey: .readingPreferences)
        try c.encode(exportedAt, forKey: .exportedAt)
    }
}

