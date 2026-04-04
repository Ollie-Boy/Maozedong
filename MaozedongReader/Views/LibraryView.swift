import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var showImporter = false
    @State private var libraryQuery = ""
    @State private var categoryFilter: DocumentCategory?

    private var filteredDocuments: [DocumentItem] {
        let q = libraryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.documents.filter { doc in
            if let f = categoryFilter, doc.category != f { return false }
            guard !q.isEmpty else { return true }
            if doc.title.localizedCaseInsensitiveContains(q) { return true }
            return doc.content.localizedCaseInsensitiveContains(q)
        }
    }

    private var groupedByCategory: [(DocumentCategory, [DocumentItem])] {
        let items = filteredDocuments
        return DocumentCategory.allCases.map { cat in
            (cat, items.filter { $0.category == cat })
        }.filter { !$0.1.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.documents.isEmpty {
                    ContentUnavailableView(
                        "暂无内容",
                        systemImage: "book.closed",
                        description: Text("点击右上角“导入”来添加 txt 或 md 文件。")
                    )
                } else if filteredDocuments.isEmpty {
                    ContentUnavailableView(
                        "无匹配结果",
                        systemImage: "magnifyingglass",
                        description: Text("试试其他关键词或清除分组筛选。")
                    )
                } else {
                    List {
                        if categoryFilter == nil {
                            ForEach(groupedByCategory, id: \.0) { section in
                                Section {
                                    ForEach(section.1) { doc in
                                        documentRow(doc)
                                    }
                                } header: {
                                    Label(section.0.displayName, systemImage: section.0.systemImage)
                                }
                            }
                        } else {
                            ForEach(filteredDocuments) { doc in
                                documentRow(doc)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("毛泽东著作")
            .searchable(text: $libraryQuery, prompt: "搜索标题与全文")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("分组", selection: $categoryFilter) {
                            Text("全部").tag(Optional<DocumentCategory>.none)
                            ForEach(DocumentCategory.allCases) { c in
                                Label(c.displayName, systemImage: c.systemImage).tag(Optional(c))
                            }
                        }
                    } label: {
                        Label("分组", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }

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

    @ViewBuilder
    private func documentRow(_ doc: DocumentItem) -> some View {
        NavigationLink {
            ReaderView(document: doc)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(doc.title)
                    .font(.headline)
                HStack(spacing: 8) {
                    Label(doc.category.displayName, systemImage: doc.category.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let progress = store.progressUTF16Offset(for: doc.id), progress > 0 {
                        Text("已读")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(doc.sourceFileName == nil ? "内置文档" : "导入：\(doc.sourceFileName ?? "")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.deleteDocument(id: doc.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .contextMenu {
            Menu("分类") {
                ForEach(DocumentCategory.allCases) { c in
                    Button {
                        store.updateCategory(documentId: doc.id, category: c)
                    } label: {
                        if doc.category == c {
                            Label(c.displayName, systemImage: "checkmark")
                        } else {
                            Text(c.displayName)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(DocumentStore(previewMode: true))
}
