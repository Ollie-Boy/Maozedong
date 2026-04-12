import SwiftUI

private struct LibrarySectionHeaderView: View {
    @EnvironmentObject private var store: DocumentStore
    let title: String
    let count: Int
    let expanded: Bool

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(store.readingPreferences.libraryAccentColor.opacity(0.85))
                .frame(width: 4, height: 18)
            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.vertical, 4)
        .textCase(nil)
    }
}

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
    @State private var showLibrarySearch = false
    @State private var poetrySectionExpanded = true
    @State private var anthologySectionExpanded = true
    @State private var collapsedAnthologyMajors: Set<Int> = []
    @State private var collapsedAnthologySubsections: Set<String> = []
    @State private var showLibrarySettings = false

    private func sortedInCategory(_ cat: DocumentCategory) -> [DocumentItem] {
        store.documents.filter { $0.category == cat }.sorted(by: DocumentItem.displaySort)
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
            let majorTitle = (title?.isEmpty == false) ? title! : (m == 99 ? "选集篇目" : "毛泽东选集")
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

    /// Nav bar compresses `NavigationLink` labels more than plain `Button`; keep both actions equally wide.
    private var libraryToolbarActionMinWidth: CGFloat { 64 }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    store.readingPreferences.libraryGradientTop,
                    store.readingPreferences.libraryGradientBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Group {
                if store.documents.isEmpty {
                    ContentUnavailableView(
                        "暂无内容",
                        systemImage: "book.closed",
                        description: Text("点击右上角“导入”来添加 txt 或 md 文件。")
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
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: "book.pages.fill")
                                            .font(.title2)
                                            .foregroundStyle(store.readingPreferences.libraryAccentColor)
                                            .symbolRenderingMode(.hierarchical)
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("继续阅读")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                            Text(cont.title)
                                                .font(.title3.weight(.semibold))
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18))
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(store.readingPreferences.backgroundColor.opacity(0.92))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(
                                                    store.readingPreferences.libraryAccentColor.opacity(0.25),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(color: Color.black.opacity(0.07), radius: 10, y: 4)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 4)
                                )
                            }
                        }
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
                                    LibrarySectionHeaderView(
                                        title: DocumentCategory.anthology.displayName,
                                        count: anth.count,
                                        expanded: anthologySectionExpanded
                                    )
                                    .environmentObject(store)
                                }
                                .buttonStyle(.plain)
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
        .navigationTitle("学习课本")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(store.readingPreferences.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        showLibrarySearch = true
                    } label: {
                        Label("搜索", systemImage: "magnifyingglass")
                            .labelStyle(.titleAndIcon)
                            .font(.body)
                            .frame(minWidth: libraryToolbarActionMinWidth, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showLibrarySettings = true
                    } label: {
                        Label("设置", systemImage: "gearshape")
                            .labelStyle(.titleAndIcon)
                            .font(.body)
                            .frame(minWidth: libraryToolbarActionMinWidth, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("导入", systemImage: "square.and.arrow.down")
                            .labelStyle(.titleAndIcon)
                            .font(.body)
                            .frame(minWidth: libraryToolbarActionMinWidth, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showLibrarySearch) {
                LibraryFullSearchView(path: $path, isPresented: $showLibrarySearch)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showLibrarySettings) {
                NavigationStack {
                    SettingsPanel(preferences: $store.readingPreferences, flushPreferencesOnDismiss: true)
                        .environmentObject(store)
                        .scrollContentBackground(.hidden)
                        .background(store.readingPreferences.backgroundColor)
                        .navigationTitle("阅读设置")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(store.readingPreferences.backgroundColor, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("完成") { showLibrarySettings = false }
                            }
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
                LibrarySectionHeaderView(
                    title: major.title,
                    count: major.subsections.reduce(0) { $0 + $1.items.count },
                    expanded: !majorCollapsed
                )
                .environmentObject(store)
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
                Text("删除")
            }
        }
        .contextMenu {
            Menu("分类") {
                ForEach(DocumentCategory.allCases) { c in
                    Button {
                        store.updateCategory(documentId: doc.id, category: c)
                    } label: {
                        if doc.category == c {
                            Text("✓ \(c.displayName)")
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
                    LibrarySectionHeaderView(
                        title: category.displayName,
                        count: items.count,
                        expanded: isExpanded
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Full-screen search (avoids `.searchable` embedding UISearchController in a huge nested List)

struct LibraryFullSearchView: View {
    @EnvironmentObject private var store: DocumentStore
    @Binding var path: NavigationPath
    @Binding var isPresented: Bool

    @State private var query = ""
    @State private var matchedIds: [UUID] = []
    @State private var isSearching = false
    @State private var searchGeneration = 0
    @State private var debounceTask: Task<Void, Never>?

    private var orderedMatches: [DocumentItem] {
        let byId = Dictionary(uniqueKeysWithValues: store.documents.map { ($0.id, $0) })
        return matchedIds.compactMap { byId[$0] }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("搜索标题与正文摘要", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("输入关键词；匹配标题与正文前段。索引就绪后会自动缩小检索范围，长文阅读可在设置里调版式。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isSearching {
                    HStack {
                        ProgressView()
                        Text("搜索中…")
                            .foregroundStyle(.secondary)
                    }
                } else if matchedIds.isEmpty {
                    Text("无匹配结果")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(orderedMatches) { doc in
                        Button {
                            isPresented = false
                            if doc.category == .poetry {
                                path.append(LibraryRoute.poetry(doc.id))
                            } else {
                                path.append(LibraryRoute.anthology(doc.id))
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(doc.title)
                                    .font(.headline)
                                if doc.category == .poetry, let y = doc.sortEpochYear {
                                    Text(String(y))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(store.readingPreferences.backgroundColor)
            .listRowBackground(store.readingPreferences.listRowBackgroundColor)
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(store.readingPreferences.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        debounceTask?.cancel()
                        isPresented = false
                    }
                }
            }
            .onChange(of: query) { _, newValue in
                scheduleSearch(for: newValue)
            }
            .onChange(of: store.librarySearchIndexReady) { _, ready in
                if ready, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    scheduleSearch(for: query)
                }
            }
            .onDisappear {
                debounceTask?.cancel()
            }
        }
    }

    private func scheduleSearch(for raw: String) {
        debounceTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            matchedIds = []
            isSearching = false
            return
        }
        isSearching = true
        searchGeneration += 1
        let generation = searchGeneration
        let needle = raw
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            let opts: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
            let toScan = store.librarySearchDocumentsToScan(for: needle)
            var found: [UUID] = []
            for (idx, doc) in toScan.enumerated() {
                if idx % 8 == 0 {
                    await Task.yield()
                    if Task.isCancelled || generation != searchGeneration { return }
                }
                if doc.title.range(of: needle, options: opts) != nil {
                    found.append(doc.id)
                    continue
                }
                if doc.textForLibrarySearch.range(of: needle, options: opts) != nil {
                    found.append(doc.id)
                }
            }
            guard generation == searchGeneration else { return }
            matchedIds = found
            isSearching = false
        }
    }
}

#Preview {
    NavigationStack {
        LibraryView(path: .constant(NavigationPath()))
    }
    .environmentObject(DocumentStore(previewMode: true))
}
