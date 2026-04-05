import SwiftUI

private struct AnthologyMinorBucket: Identifiable {
    let id: String
    let title: String
    let items: [DocumentItem]
}

private struct AnthologyMajorGroup: Identifiable {
    let id: Int
    let title: String
    let subsections: [AnthologyMinorBucket]
}

struct LibraryView: View {
    @EnvironmentObject private var store: DocumentStore
    @Binding var path: NavigationPath
    @State private var showImporter = false
    @State private var libraryQuery = ""
    @State private var categoryFilter: DocumentCategory?
    @State private var poetrySectionExpanded = true
    @State private var anthologySectionExpanded = true
    @State private var collapsedAnthologyMajors: Set<Int> = []
    @State private var collapsedAnthologySubsections: Set<String> = []

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

    private func anthologyMajorGroups(from items: [DocumentItem]) -> [AnthologyMajorGroup] {
        let sorted = items.sorted(by: DocumentItem.displaySort)
        var byMajor: [Int: [DocumentItem]] = [:]
        var majorKeys: [Int] = []
        for doc in sorted {
            let m = doc.anthologyMajorOrder ?? 99
            if byMajor[m] == nil {
                majorKeys.append(m)
                byMajor[m] = []
            }
            byMajor[m]?.append(doc)
        }
        return majorKeys.map { m in
            let docs = byMajor[m] ?? []
            let title = docs.first.flatMap { $0.anthologyMajorTitle }?.trimmingCharacters(in: .whitespacesAndNewlines)
            let majorTitle = (title?.isEmpty == false) ? title! : (m == 99 ? "选集篇目" : "选集")
            return AnthologyMajorGroup(id: m, title: majorTitle, subsections: anthologyMinorBuckets(from: docs))
        }
    }

    private func anthologyMinorBuckets(from items: [DocumentItem]) -> [AnthologyMinorBucket] {
        let sorted = items.sorted(by: DocumentItem.displaySort)
        var dict: [String: [DocumentItem]] = [:]
        var order: [String] = []
        for doc in sorted {
            let sub = doc.anthologySubOrder ?? 0
            let sec = doc.anthologySectionTitle ?? ""
            let key = "\(sub)|\(sec)"
            if dict[key] == nil {
                order.append(key)
                dict[key] = []
            }
            dict[key]?.append(doc)
        }
        return order.compactMap { k in
            guard let arr = dict[k], !arr.isEmpty else { return nil }
            let subTitle = arr.first?.anthologySectionTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let display = (subTitle?.isEmpty == false) ? subTitle! : "篇目"
            return AnthologyMinorBucket(id: k, title: display, items: arr)
        }
    }

    private func subsectionCollapseKey(majorId: Int, subId: String) -> String {
        "\(majorId)|\(subId)"
    }

    var body: some View {
        ZStack {
                store.readingPreferences.backgroundColor.ignoresSafeArea()
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
                                if let cont = store.continueReadingDocument {
                                    Section {
                                        Button {
                                            if cont.category == .poetry {
                                                path.append(LibraryRoute.poetry(cont.id))
                                            } else {
                                                path.append(LibraryRoute.anthology(cont.id))
                                            }
                                        } label: {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("继续阅读")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text(cont.title)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                    }
                                }
                                if categoryFilter == nil {
                                    CollapsibleLibrarySection(
                                        category: .poetry,
                                        isExpanded: $poetrySectionExpanded,
                                        items: sortedInCategory(.poetry)
                                    ) { doc in
                                        documentRow(doc, labelLeadingInset: 0)
                                    }

                                    let anth = sortedInCategory(.anthology)
                                    if !anth.isEmpty {
                                        Section {
                                            if anthologySectionExpanded {
                                                ForEach(anthologyMajorGroups(from: anth)) { major in
                                                    anthologyMajorSection(major: major)
                                                }
                                            }
                                        } header: {
                                            Button {
                                                anthologySectionExpanded.toggle()
                                            } label: {
                                                HStack {
                                                    Image(systemName: anthologySectionExpanded ? "chevron.down" : "chevron.right")
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(.secondary)
                                                    Label(DocumentCategory.anthology.displayName, systemImage: DocumentCategory.anthology.systemImage)
                                                    Spacer()
                                                    Text("\(anth.count)")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                .textCase(nil)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                } else {
                                    ForEach(filteredDocuments.sorted(by: DocumentItem.displaySort)) { doc in
                                        documentRow(doc, labelLeadingInset: 0)
                                    }
                                }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listRowBackground(store.readingPreferences.listRowBackgroundColor)
                    .listSectionSpacing(.compact)
                }
                }
        }
        .navigationTitle("毛泽东著作")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(store.readingPreferences.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
                            .environmentObject(store)
                            .scrollContentBackground(.hidden)
                            .background(store.readingPreferences.backgroundColor)
                            .navigationTitle("阅读设置")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(store.readingPreferences.backgroundColor, for: .navigationBar)
                            .toolbarBackground(.visible, for: .navigationBar)
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
            .navigationDestination(for: LibraryRoute.self) { route in
                switch route {
                case let .poetry(id):
                    if let doc = store.documents.first(where: { $0.id == id }) {
                        PoetryReaderPager(allDocuments: store.documents, initial: doc) {
                            path.removeLast()
                        }
                    } else {
                        Text("篇目已不存在").onAppear { path.removeLast() }
                    }
                case let .anthology(id):
                    if let doc = store.documents.first(where: { $0.id == id }) {
                        AnthologyReaderPager(allDocuments: store.documents, initial: doc) {
                            path.removeLast()
                        }
                    } else {
                        Text("篇目已不存在").onAppear { path.removeLast() }
                    }
                }
            }
    }

    @ViewBuilder
    private func anthologyMajorSection(major: AnthologyMajorGroup) -> some View {
        let majorCollapsed = collapsedAnthologyMajors.contains(major.id)
        Section {
            if !majorCollapsed {
                if major.subsections.count == 1, let only = major.subsections.first {
                    ForEach(only.items) { doc in
                        documentRow(doc, labelLeadingInset: 0)
                    }
                } else {
                    ForEach(major.subsections) { sub in
                        let subKey = subsectionCollapseKey(majorId: major.id, subId: sub.id)
                        let subCollapsed = collapsedAnthologySubsections.contains(subKey)
                        Section {
                            if !subCollapsed {
                                ForEach(sub.items) { doc in
                                    documentRow(doc, labelLeadingInset: 22)
                                }
                            }
                        } header: {
                            Button {
                                if subCollapsed {
                                    collapsedAnthologySubsections.remove(subKey)
                                } else {
                                    collapsedAnthologySubsections.insert(subKey)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: subCollapsed ? "chevron.right" : "chevron.down")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(sub.title)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("\(sub.items.count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 14)
                                .textCase(nil)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        } header: {
            Button {
                if majorCollapsed {
                    collapsedAnthologyMajors.remove(major.id)
                } else {
                    collapsedAnthologyMajors.insert(major.id)
                }
            } label: {
                HStack {
                    Image(systemName: majorCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(major.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(major.subsections.reduce(0) { $0 + $1.items.count })")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .textCase(nil)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func documentRow(_ doc: DocumentItem, labelLeadingInset: CGFloat = 0) -> some View {
        Group {
            if doc.category == .poetry {
                Button {
                    path.append(LibraryRoute.poetry(doc.id))
                } label: {
                    rowLabel(doc)
                        .padding(.leading, labelLeadingInset)
                }
            } else {
                Button {
                    path.append(LibraryRoute.anthology(doc.id))
                } label: {
                    rowLabel(doc)
                        .padding(.leading, labelLeadingInset)
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
        if doc.category == .poetry {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(doc.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    if let y = doc.sortEpochYear {
                        Text(String(format: "%d", y))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .padding(.top, 2)
                    }
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
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(doc.title)
                    .font(.headline)
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
    NavigationStack {
        LibraryView(path: .constant(NavigationPath()))
    }
    .environmentObject(DocumentStore(previewMode: true))
}
