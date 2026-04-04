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
        let sorted = urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var items: [DocumentItem] = []
        for url in sorted {
            do {
                let imported = try PlainTextFileImporter.parse(url: url)
                let category = PlainTextFileImporter.inferredCategory(
                    fileName: url.lastPathComponent,
                    content: imported.content
                )
                items.append(
                    DocumentItem(
                        title: imported.title,
                        content: imported.content,
                        sourceFileName: url.lastPathComponent,
                        category: category
                    )
                )
            } catch {
                continue
            }
        }
        return items
    }
}
