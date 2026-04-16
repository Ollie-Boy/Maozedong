import SwiftUI

private struct LibrarySectionHeaderView: View {
    @EnvironmentObject private var store: DocumentStore
    let title: String
    let count: Int
    let expanded: Bool
    /// Extra leading inset (e.g. nested 选集分期 under a volume).
    var leadingInset: CGFloat = 0

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
                .background(
                    store.readingPreferences.libraryAccentColor.opacity(0.14),
                    in: Capsule()
                )
        }
        .padding(.vertical, 8)
        .padding(.leading, 16 + leadingInset)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(store.readingPreferences.backgroundColor)
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
    @State private var showImportSetup = false
    @State private var showFileImporter = false
    @State private var importFolderCategory: DocumentCategory = .poetry
    @State private var importTargetFolderIdString = ""
    @State private var importNewFolderTitle = ""
    @State private var showLibrarySearch = false
    @State private var poetrySectionExpanded = true
    @State private var anthologySectionExpanded = true
    @State private var collapsedAnthologyMajors: Set<Int> = []
    @State private var collapsedAnthologySubsections: Set<String> = []
    @State private var collapsedPoetryFolders: Set<UUID> = []
    @State private var collapsedAnthologyUserFolders: Set<UUID> = []
    @State private var showLibrarySettings = false
    @State private var folderToRename: LibraryFolder?
    @State private var renameFolderDraft = ""
    @State private var folderPendingDelete: UUID?

    private func sortedInCategory(_ cat: DocumentCategory) -> [DocumentItem] {
        store.documents.filter { $0.category == cat }.sorted(by: DocumentItem.displaySort)
    }

    private func folders(for category: DocumentCategory) -> [LibraryFolder] {
        store.libraryFolders.filter { $0.category == category }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func documents(in folder: LibraryFolder) -> [DocumentItem] {
        store.documents.filter { $0.libraryFolderId == folder.id }.sorted(by: DocumentItem.displaySort)
    }

    private func poetryUngrouped() -> [DocumentItem] {
        store.documents.filter { $0.category == .poetry && $0.libraryFolderId == nil }.sorted(by: DocumentItem.displaySort)
    }

    private func anthologyBundledUngrouped() -> [DocumentItem] {
        store.documents.filter { $0.category == .anthology && $0.isBundledAnthology && $0.libraryFolderId == nil }
            .sorted(by: DocumentItem.displaySort)
    }

    private func anthologyImportUngrouped() -> [DocumentItem] {
        store.documents.filter { $0.category == .anthology && !$0.isBundledAnthology && $0.libraryFolderId == nil }
            .sorted(by: DocumentItem.displaySort)
    }

    private func importTargetFolderId() -> UUID? {
        guard !importTargetFolderIdString.isEmpty else { return nil }
        return UUID(uuidString: importTargetFolderIdString)
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

    @ViewBuilder
    private func poetryLibrarySection() -> some View {
        let items = sortedInCategory(.poetry)
        if !items.isEmpty {
            Section {
                Button {
                    poetrySectionExpanded.toggle()
                } label: {
                    LibrarySectionHeaderView(
                        title: DocumentCategory.poetry.displayName,
                        count: items.count,
                        expanded: poetrySectionExpanded
                    )
                    .environmentObject(store)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(store.readingPreferences.backgroundColor)

                if poetrySectionExpanded {
                    let loose = poetryUngrouped()
                    ForEach(loose) { doc in
                        documentRow(doc, labelLeadingInset: 0, moveCategory: .poetry)
                    }

                    ForEach(folders(for: .poetry)) { folder in
                        let collapsed = collapsedPoetryFolders.contains(folder.id)
                        let folderDocs = documents(in: folder)
                        Button {
                            if collapsed {
                                collapsedPoetryFolders.remove(folder.id)
                            } else {
                                collapsedPoetryFolders.insert(folder.id)
                            }
                        } label: {
                            LibrarySectionHeaderView(
                                title: folder.title,
                                count: folderDocs.count,
                                expanded: !collapsed,
                                leadingInset: 6
                            )
                            .environmentObject(store)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("重命名") {
                                folderToRename = folder
                                renameFolderDraft = folder.title
                            }
                            Button("删除目录", role: .destructive) {
                                folderPendingDelete = folder.id
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(store.readingPreferences.backgroundColor)

                        if !collapsed {
                            ForEach(folderDocs) { doc in
                                documentRow(doc, labelLeadingInset: 22, moveCategory: .poetry)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func anthologyLibrarySection() -> some View {
        let bundled = anthologyBundledUngrouped()
        let userFolders = folders(for: .anthology)
        let importsLoose = anthologyImportUngrouped()
        let anthCount = bundled.count + importsLoose.count + userFolders.map { documents(in: $0).count }.reduce(0, +)
        if anthCount > 0 {
            Section {
                Button {
                    anthologySectionExpanded.toggle()
                } label: {
                    LibrarySectionHeaderView(
                        title: DocumentCategory.anthology.displayName,
                        count: anthCount,
                        expanded: anthologySectionExpanded
                    )
                    .environmentObject(store)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(store.readingPreferences.backgroundColor)

                if anthologySectionExpanded {
                    if !bundled.isEmpty {
                        ForEach(anthologyMajorGroups(from: bundled)) { major in
                            anthologyMajorSection(major: major)
                        }
                    }

                    ForEach(userFolders) { folder in
                        let collapsed = collapsedAnthologyUserFolders.contains(folder.id)
                        let folderDocs = documents(in: folder)
                        Button {
                            if collapsed {
                                collapsedAnthologyUserFolders.remove(folder.id)
                            } else {
                                collapsedAnthologyUserFolders.insert(folder.id)
                            }
                        } label: {
                            LibrarySectionHeaderView(
                                title: folder.title,
                                count: folderDocs.count,
                                expanded: !collapsed,
                                leadingInset: 6
                            )
                            .environmentObject(store)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("重命名") {
                                folderToRename = folder
                                renameFolderDraft = folder.title
                            }
                            Button("删除目录", role: .destructive) {
                                folderPendingDelete = folder.id
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(store.readingPreferences.backgroundColor)

                        if !collapsed {
                            ForEach(folderDocs) { doc in
                                documentRow(doc, labelLeadingInset: 22, moveCategory: .anthology)
                            }
                        }
                    }

                    ForEach(importsLoose) { doc in
                        documentRow(doc, labelLeadingInset: 0, moveCategory: .anthology)
                    }
                }
            }
        }
    }

    var body: some View {
        ZStack {
            // One canvas color with nav + toolbar + list (no separate gradient “card” vs chrome).
            store.readingPreferences.backgroundColor
                .allowsHitTesting(false)
                .ignoresSafeArea()

            Group {
                if store.documents.isEmpty {
                    ContentUnavailableView("暂无内容", systemImage: "book.closed")
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
                                            .foregroundStyle(store.readingPreferences.libraryAccentColor.opacity(0.85))
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
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 12, leading: 22, bottom: 12, trailing: 22))
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(store.readingPreferences.backgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(
                                                    store.readingPreferences.libraryAccentColor.opacity(0.14),
                                                    lineWidth: 1
                                                )
                                        )
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 14)
                                )
                            }
                            .listSectionSeparator(.hidden)
                        }
                        poetryLibrarySection()

                        anthologyLibrarySection()
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(store.readingPreferences.backgroundColor)
                    .listRowBackground(store.readingPreferences.backgroundColor)
                    .listSectionSpacing(.compact)
                }
            }
        }
        .navigationTitle("学习课本")
        // Large title area has regressed on newer iOS as a non-interactive overlay blocking the first list rows
        // (e.g. “继续阅读”); inline title avoids the ghost hit-stealer while keeping the same toolbar chrome.
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(store.readingPreferences.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(store.readingPreferences.theme == .dark ? .dark : .light, for: .navigationBar)
        .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        showLibrarySearch = true
                    } label: {
                        Label("搜索", systemImage: "magnifyingglass")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("搜索")
                    .buttonStyle(.plain)

                    Button {
                        showLibrarySettings = true
                    } label: {
                        Label("设置", systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("设置")
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        importFolderCategory = .poetry
                        importTargetFolderIdString = ""
                        importNewFolderTitle = ""
                        showImportSetup = true
                    } label: {
                        Label("导入", systemImage: "square.and.arrow.down")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("导入")
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showImportSetup) {
                NavigationStack {
                    Form {
                        Picker("分类", selection: $importFolderCategory) {
                            Text(DocumentCategory.poetry.displayName).tag(DocumentCategory.poetry)
                            Text(DocumentCategory.anthology.displayName).tag(DocumentCategory.anthology)
                        }
                        .onChange(of: importFolderCategory) { _, _ in
                            importTargetFolderIdString = ""
                            importNewFolderTitle = ""
                        }
                        Picker("放入子目录", selection: $importTargetFolderIdString) {
                            Text("不放入子目录").tag("")
                            ForEach(folders(for: importFolderCategory)) { f in
                                Text(f.title).tag(f.id.uuidString)
                            }
                        }
                        Section {
                            TextField("新子目录名称（可选）", text: $importNewFolderTitle)
                                .textInputAutocapitalization(.never)
                            Button("创建子目录并用于本次导入") {
                                let name = importNewFolderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !name.isEmpty else { return }
                                if let id = store.addLibraryFolder(category: importFolderCategory, title: name) {
                                    importTargetFolderIdString = id.uuidString
                                    importNewFolderTitle = ""
                                }
                            }
                            .disabled(importNewFolderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        } header: {
                            Text("需要新目录时")
                        }
                    }
                    .navigationTitle("导入")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") { showImportSetup = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("选择文件") {
                                showImportSetup = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    showFileImporter = true
                                }
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: PlainTextFileImporter.supportedContentTypes,
                allowsMultipleSelection: true
            ) { result in
                do {
                    let urls = try result.get()
                    try store.importFiles(from: urls, forcedCategory: importFolderCategory, libraryFolderId: importTargetFolderId())
                } catch {
                    store.errorMessage = error.localizedDescription
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
            .alert("导入失败", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.clearError() } }
            ), actions: {
                Button("确定") { store.clearError() }
            }, message: {
                Text(store.errorMessage ?? "")
            })
            .sheet(item: $folderToRename) { folder in
                NavigationStack {
                    Form {
                        TextField("名称", text: $renameFolderDraft)
                    }
                    .navigationTitle("重命名子目录")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") { folderToRename = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                store.renameLibraryFolder(id: folder.id, newTitle: renameFolderDraft)
                                folderToRename = nil
                            }
                            .disabled(renameFolderDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.height(160)])
            }
            .confirmationDialog(
                "删除子目录？其中的篇目将移回未分组。",
                isPresented: Binding(
                    get: { folderPendingDelete != nil },
                    set: { if !$0 { folderPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    if let id = folderPendingDelete {
                        store.deleteLibraryFolder(id: id)
                    }
                    folderPendingDelete = nil
                }
                Button("取消", role: .cancel) { folderPendingDelete = nil }
            }
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
        // Use Group (not nested Section) so volume / subsection titles never use UITableView sticky header chrome.
        Group {
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
            .listRowSeparator(.hidden)
            .listRowBackground(store.readingPreferences.backgroundColor)

            if !majorCollapsed {
                if major.subsections.count == 1, let only = major.subsections.first {
                    ForEach(only.items) { doc in
                        documentRow(doc, labelLeadingInset: 0)
                    }
                } else {
                    ForEach(major.subsections) { sub in
                        let subKey = subsectionCollapseKey(majorId: major.id, subId: sub.id)
                        let subCollapsed = collapsedAnthologySubsections.contains(subKey)
                        Button {
                            if subCollapsed {
                                collapsedAnthologySubsections.remove(subKey)
                            } else {
                                collapsedAnthologySubsections.insert(subKey)
                            }
                        } label: {
                            LibrarySectionHeaderView(
                                title: sub.title,
                                count: sub.items.count,
                                expanded: !subCollapsed,
                                leadingInset: 6
                            )
                            .environmentObject(store)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(store.readingPreferences.backgroundColor)

                        if !subCollapsed {
                            ForEach(sub.items) { doc in
                                documentRow(doc, labelLeadingInset: 22)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func documentRow(_ doc: DocumentItem, labelLeadingInset: CGFloat = 0, moveCategory: DocumentCategory? = nil) -> some View {
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
            if let mc = moveCategory, doc.category == mc {
                Menu("移动到子目录") {
                    Button("不放入子目录") {
                        store.assignDocuments(documentIds: [doc.id], toFolderId: nil)
                    }
                    ForEach(folders(for: mc)) { f in
                        Button {
                            store.assignDocuments(documentIds: [doc.id], toFolderId: f.id)
                        } label: {
                            if doc.libraryFolderId == f.id {
                                Text("✓ \(f.title)")
                            } else {
                                Text(f.title)
                            }
                        }
                    }
                }
            }
        }
        .listRowBackground(store.readingPreferences.backgroundColor)
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
                TextField("搜索", text: $query)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .searchQueryFieldChrome(store.readingPreferences)
                    .listRowSeparator(.hidden)
                    .listRowBackground(store.readingPreferences.backgroundColor)
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if isSearching {
                        HStack {
                            ProgressView()
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
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(store.readingPreferences.backgroundColor)
            .listRowBackground(store.readingPreferences.backgroundColor)
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(store.readingPreferences.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(store.readingPreferences.theme == .dark ? .dark : .light, for: .navigationBar)
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
