import Foundation

enum BundledSampleImporter {
    /// Markdown files shipped under `SampleContent/` in the app bundle (Xcode target → Copy Bundle Resources).
    static func loadDocuments() -> [DocumentItem] {
        let bundle = Bundle.main
        var urls = bundle.urls(forResourcesWithExtension: "md", subdirectory: "SampleContent") ?? []
        if urls.isEmpty {
            urls = (bundle.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? [])
                .filter { $0.path.contains("SampleContent") }
        }
        if urls.isEmpty {
            let bases = ["沁园春·雪", "语录摘录", "文章示例"]
            urls = bases.compactMap { bundle.url(forResource: $0, withExtension: "md", subdirectory: nil) }
        }
        let sorted = urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var items: [DocumentItem] = []
        for url in sorted {
            do {
                let imported = try PlainTextFileImporter.parse(url: url)
                let category = PlainTextFileImporter.inferredCategory(
                    fileName: url.lastPathComponent,
                    content: imported.content
                )
                var sortY: Int?
                var sortM: Int?
                if url.lastPathComponent.contains("沁园春") {
                    sortY = 1936
                    sortM = 2
                }
                items.append(
                    DocumentItem(
                        title: imported.title,
                        content: imported.content,
                        sourceFileName: url.lastPathComponent,
                        category: category,
                        sortEpochYear: sortY,
                        sortEpochMonth: sortM
                    )
                )
            } catch {
                continue
            }
        }
        return items
    }
}
