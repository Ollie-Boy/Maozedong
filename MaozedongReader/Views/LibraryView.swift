import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            Group {
                if store.documents.isEmpty {
                    ContentUnavailableView(
                        "暂无内容",
                        systemImage: "book.closed",
                        description: Text("点击右上角“导入”来添加 txt 或 md 文件。")
                    )
                } else {
                    List {
                        ForEach(store.documents) { doc in
                            NavigationLink {
                                ReaderView(document: doc)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(doc.title)
                                        .font(.headline)
                                    Text(doc.sourceFileName == nil ? "内置文档" : "导入文档")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: store.deleteDocuments)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("毛泽东著作")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("设置") {
                        SettingsPanel(preferences: $store.readingPreferences)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("导入") {
                        showImporter = true
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: PlainTextFileImporter.supportedContentTypes,
                allowsMultipleSelection: true
            ) { result in
                do {
                    let urls = try result.get()
                    try store.importFiles(from: urls)
                } catch {
                    store.errorMessage = error.localizedDescription
                }
            }
            .alert("导入失败", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.clearError() } }
            ), actions: {
                Button("确定") { store.clearError() }
            }, message: {
                Text(store.errorMessage ?? "")
            })
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(DocumentStore(previewMode: true))
}
