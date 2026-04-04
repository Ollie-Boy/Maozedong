import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var showImporter = false
    @State private var libraryQuery = ""
    @State private var categoryFilter: DocumentCategory?
    @State private var poetrySectionExpanded = true
    @State private var anthologySectionExpanded = true

    private var filteredDocuments: [DocumentItem] {
        let q = libraryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.documents.filter { doc in
            if let f = categoryFilter, doc.category != f { return false }
            guard !q.isEmpty else { return true }
            if doc.title.localizedCaseInsensitiveContains(q) { return true }
            return doc.content.localizedCaseInsensitiveContains(q)
        }
    }

    private func sortedInCategory(_ cat: DocumentCategory) -> [DocumentItem] {
        filteredDocuments.filter { $0.category == cat }.sorted(by: DocumentItem.displaySort)
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
                            CollapsibleLibrarySection(
                                category: .poetry,
                                isExpanded: $poetrySectionExpanded,
                                items: sortedInCategory(.poetry)
                            ) { doc in
                                documentRow(doc)
                            }
                            CollapsibleLibrarySection(
                                category: .anthology,
                                isExpanded: $anthologySectionExpanded,
                                items: sortedInCategory(.anthology)
                            ) { doc in
                                documentRow(doc)
                            }
                        } else {
                            ForEach(filteredDocuments.sorted(by: DocumentItem.displaySort)) { doc in
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
                    Button {
                        Task {
                            await store.syncRemoteAnthologyFromGitHub()
                        }
                    } label: {
                        if store.isSyncingRemoteAnthology {
                            ProgressView()
                        } else {
                            Label("同步选集", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(store.isSyncingRemoteAnthology)
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
        Group {
            if doc.category == .poetry {
                NavigationLink {
                    PoetryReaderPager(allDocuments: store.documents, initial: doc)
                } label: {
                    rowLabel(doc)
                }
            } else {
                NavigationLink {
                    AnthologyReaderPager(allDocuments: store.documents, initial: doc)
                } label: {
                    rowLabel(doc)
                }
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

    @ViewBuilder
    private func rowLabel(_ doc: DocumentItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(doc.title)
                .font(.headline)
            HStack(spacing: 8) {
                if doc.category == .poetry, let y = doc.sortEpochYear {
                    Text(String(format: "%d", y))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let progress = store.progressUTF16Offset(for: doc.id), progress > 0 {
                    Text("已读")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct CollapsibleLibrarySection<Row: View>: View {
    let category: DocumentCategory
    @Binding var isExpanded: Bool
    let items: [DocumentItem]
    @ViewBuilder let row: (DocumentItem) -> Row

    var body: some View {
        if !items.isEmpty {
            Section {
                if isExpanded {
                    ForEach(items) { doc in
                        row(doc)
                    }
                }
            } header: {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Label(category.displayName, systemImage: category.systemImage)
                        Spacer()
                        Text("\(items.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .textCase(nil)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(DocumentStore(previewMode: true))
}
