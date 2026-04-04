import Foundation

@MainActor
final class DocumentStore: ObservableObject {
    @Published var documents: [DocumentItem] = []
    @Published var readingPreferences: ReadingPreferences = .default {
        didSet {
            saveReadingPreferences()
        }
    }
    @Published var errorMessage: String?

    private let fileManager = FileManager.default
    private let documentsMetadataFileName = "documents.json"
    private let readingPreferencesFileName = "reading_preferences.json"
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

    init(previewMode: Bool = false) {
        self.isPreviewMode = previewMode
        guard !previewMode else {
            documents = DocumentItem.previewItems
            readingPreferences = .default
            return
        }

        loadAll()
        seedIfNeeded()
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
                let item = DocumentItem(
                    title: imported.title,
                    content: imported.content,
                    sourceFileName: url.lastPathComponent
                )
                documents.insert(item, at: 0)
            } catch {
                errorMessage = "导入 \(url.lastPathComponent) 失败：\(error.localizedDescription)"
            }
        }

        try saveDocuments()
    }

    func deleteDocuments(at offsets: IndexSet) {
        documents.remove(atOffsets: offsets)
        do {
            try saveDocuments()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
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

    func clearError() {
        errorMessage = nil
    }

    private func loadAll() {
        loadDocuments()
        loadReadingPreferences()
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

    private func saveDocuments() throws {
        let data = try JSONEncoder().encode(documents)
        try data.write(to: documentsMetadataURL, options: .atomic)
    }

    private func seedIfNeeded() {
        guard !isPreviewMode else { return }
        guard documents.isEmpty else { return }

        let sampleTitle = "示例：沁园春·雪"
        let sampleContent = """
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
        """

        do {
            let sample = DocumentItem(
                title: sampleTitle,
                content: sampleContent,
                sourceFileName: "sample.txt"
            )
            documents = [sample]
            try saveDocuments()
        } catch {
            errorMessage = "写入示例文档失败：\(error.localizedDescription)"
        }
    }
}
