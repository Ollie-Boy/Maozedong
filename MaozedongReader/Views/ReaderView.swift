import SwiftUI

private struct ScrollContentMinYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct BlockFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct ViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ReaderView: View {
    @EnvironmentObject private var store: DocumentStore
    @StateObject private var speechService = SpeechService()

    let document: DocumentItem
    /// When false (e.g. horizontal pager siblings), do not register nav items so only the active page owns the navigation bar.
    var presentsNavigationChrome: Bool = true
    /// While the horizontal pager is dragging or finishing a page turn, lock vertical scroll on **all** slots (left/center/right).
    var lockVerticalScrollWhilePaging: Bool = false
    @State private var showingSettings = false
    @State private var showingTOC = false
    @State private var showingSearch = false
    @State private var searchQuery = ""
    @State private var showExportShare = false
    @State private var exportShareURL: URL?
    @State private var exportError: String?

    @State private var cachedBlocks: [MarkdownBlock] = []
    @State private var plainSegments: [(text: String, utf16Start: Int)] = []
    @State private var useMarkdown = false

    @State private var scrollContentMinY: CGFloat = 0
    @State private var blockFrames: [UUID: CGRect] = [:]
    @State private var viewportHeight: CGFloat = 600
    @State private var blockFramesDebounceTask: Task<Void, Never>?

    @State private var scrollToBlockId: UUID?
    @State private var progressSaveTask: Task<Void, Never>?
    @State private var expandedNoteBlockIds: Set<UUID> = []
    /// Filled asynchronously when `document.contentExternalized` (body on disk, not in `documents.json`).
    @State private var loadedBody: String?

    private let scrollSpaceName = "readerScroll"
    /// Coalesce hundreds of per-block preference merges while vertically scrolling long articles.
    private static let blockFramesDebounceNs: UInt64 = 90_000_000

    private var readerSourceText: String {
        document.contentExternalized ? (loadedBody ?? "") : document.content
    }

    var body: some View {
        let blocks = displayBlocks
        let headings = tocEntries(from: blocks)

        Group {
            if document.contentExternalized && loadedBody == nil && presentsNavigationChrome {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                readerScrollRoot(blocks: blocks)
            }
        }
            .modifier(ReaderBarTitleModifier(title: document.title, useToolbarPrincipal: !presentsNavigationChrome))
            .toolbarBackground(store.readingPreferences.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(store.readingPreferences.backgroundColor, for: .bottomBar)
            .toolbarBackground(.visible, for: .bottomBar)
            .toolbar {
                if presentsNavigationChrome {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showingTOC = true
                        } label: {
                            Label("目录", systemImage: "list.bullet")
                        }
                        .disabled(headings.isEmpty)

                        Button {
                            searchQuery = ""
                            showingSearch = true
                        } label: {
                            Label("搜索", systemImage: "magnifyingglass")
                        }

                        Button {
                            exportCurrentDocument()
                        } label: {
                            Label("导出", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            if speechService.isSpeaking {
                                speechService.stop()
                            } else {
                                speechService.speak(speechPlainText)
                            }
                        } label: {
                            Label(
                                speechService.isSpeaking ? "停止朗读" : "朗读",
                                systemImage: speechService.isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
                            )
                        }

                        Button {
                            showingSettings = true
                        } label: {
                            Label("阅读设置", systemImage: "textformat.size")
                        }
                    }
                }
            }
        .sheet(isPresented: $showingSettings) {
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
                            Button("完成") {
                                showingSettings = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingTOC) {
            NavigationStack {
                List {
                    ForEach(headings, id: \.block.id) { entry in
                        Button {
                            scrollToBlockId = entry.block.id
                            showingTOC = false
                        } label: {
                            Text(entry.title)
                                .padding(.leading, CGFloat(entry.level - 1) * 12)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(store.readingPreferences.backgroundColor)
                .listRowBackground(store.readingPreferences.listRowBackgroundColor)
                .navigationTitle("目录")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(store.readingPreferences.backgroundColor, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { showingTOC = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            NavigationStack {
                ReaderSearchSheet(
                    blocks: blocks,
                    query: $searchQuery,
                    onSelect: { id in
                        scrollToBlockId = id
                        showingSearch = false
                    }
                )
                .environmentObject(store)
            }
        }
        .sheet(isPresented: $showExportShare, onDismiss: {
            if let u = exportShareURL {
                try? FileManager.default.removeItem(at: u)
            }
            exportShareURL = nil
        }) {
            if let url = exportShareURL {
                ActivityShareSheet(items: [url])
            }
        }
        .alert("导出", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("好", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .onAppear {
            if presentsNavigationChrome {
                store.recordLastOpenedDocument(documentId: document.id)
            }
            loadBodyIfNeeded()
        }
        .onChange(of: presentsNavigationChrome) { _, chrome in
            if chrome {
                loadBodyIfNeeded()
                store.recordLastOpenedDocument(documentId: document.id)
            } else {
                progressSaveTask?.cancel()
                let b = displayBlocks
                let utf16 = currentProgressUTF16(blocks: b) ?? store.progressUTF16Offset(for: document.id) ?? 0
                store.setReadingProgress(documentId: document.id, utf16Offset: utf16)
                loadedBody = nil
                cachedBlocks = []
                plainSegments = []
            }
        }
        .onChange(of: document.id) { _, _ in
            expandedNoteBlockIds = []
            blockFramesDebounceTask?.cancel()
            blockFramesDebounceTask = nil
            loadedBody = nil
            if presentsNavigationChrome {
                loadBodyIfNeeded()
            } else {
                prepareContent()
            }
        }
        .onChange(of: document.content) { _, _ in
            if !document.contentExternalized {
                prepareContent()
            }
        }
        .onDisappear {
            progressSaveTask?.cancel()
            blockFramesDebounceTask?.cancel()
            blockFramesDebounceTask = nil
            let utf16 = currentProgressUTF16(blocks: blocks) ?? store.progressUTF16Offset(for: document.id) ?? 0
            store.setReadingProgress(documentId: document.id, utf16Offset: utf16)
        }
    }

    private func exportCurrentDocument() {
        let name = document.title.replacingOccurrences(of: "/", with: "-")
        let base = name.isEmpty ? "export" : name
        let body = document.contentExternalized ? (store.resolvedBody(for: document) ?? "") : document.content
        let md = "# \(document.title)\n\n\(body)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(base).md")
        do {
            try md.data(using: .utf8)?.write(to: url, options: .atomic)
            exportShareURL = url
            showExportShare = true
        } catch {
            exportError = "导出失败：\(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private func readerScrollRoot(blocks: [MarkdownBlock]) -> some View {
        ZStack {
            store.readingPreferences.backgroundColor
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CGFloat(store.readingPreferences.readerBlockSpacing)) {
                        Color.clear
                            .frame(height: 0)
                            .background(
                                GeometryReader { g in
                                    Color.clear
                                        .allowsHitTesting(false)
                                        .preference(
                                            key: ScrollContentMinYKey.self,
                                            value: g.frame(in: .named(scrollSpaceName)).minY
                                        )
                                }
                            )

                        ForEach(blocks) { item in
                            blockView(item)
                                .id(item.id)
                                .background {
                                    // Per-block frames are only needed for fine-grained reading progress on the
                                    // active page. Sibling ReaderViews in the horizontal pager would otherwise
                                    // merge hundreds of preferences on every vertical scroll → high CPU when swiping fast.
                                    if presentsNavigationChrome {
                                        GeometryReader { g in
                                            Color.clear
                                                .allowsHitTesting(false)
                                                .preference(
                                                    key: BlockFramesKey.self,
                                                    value: [item.id: g.frame(in: .named(scrollSpaceName))]
                                                )
                                        }
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: store.readingPreferences.readerMaxColumnWidth > 0
                        ? CGFloat(store.readingPreferences.readerMaxColumnWidth)
                        : .infinity)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, CGFloat(store.readingPreferences.readerHorizontalPadding))
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(!presentsNavigationChrome || lockVerticalScrollWhilePaging)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .allowsHitTesting(false)
                            .preference(key: ViewportHeightKey.self, value: geo.size.height)
                    }
                )
                .coordinateSpace(name: scrollSpaceName)
                .onPreferenceChange(ScrollContentMinYKey.self) { scrollContentMinY = $0 }
                .onPreferenceChange(BlockFramesKey.self) { merged in
                    blockFramesDebounceTask?.cancel()
                    blockFramesDebounceTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: Self.blockFramesDebounceNs)
                        guard !Task.isCancelled else { return }
                        blockFrames = merged
                    }
                }
                .onPreferenceChange(ViewportHeightKey.self) { h in
                    if h > 1 { viewportHeight = h }
                }
                // Off-screen pager siblings still receive layout preferences; saving progress from every page
                // republished `readerState` and caused a feedback loop (freeze / 100% CPU).
                .onChange(of: scrollContentMinY) { _, _ in
                    if presentsNavigationChrome { scheduleProgressSave(blocks: blocks) }
                }
                .onChange(of: blockFrames) { _, _ in
                    if presentsNavigationChrome { scheduleProgressSave(blocks: blocks) }
                }
                .onAppear {
                    restoreScrollIfNeeded(proxy: proxy, blocks: blocks)
                }
                .onChange(of: scrollToBlockId) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                    scrollToBlockId = nil
                }
            }
        }
    }

    private var displayBlocks: [MarkdownBlock] {
        if useMarkdown, !cachedBlocks.isEmpty {
            return cachedBlocks
        }
        return plainSegments.map { seg in
            MarkdownBlock(
                id: StableUUID.from(document.id.uuidString, "\(seg.utf16Start)"),
                kind: .paragraph(lines: [seg.text]),
                plainUTF16Start: seg.utf16Start
            )
        }
    }

    private func loadBodyIfNeeded() {
        if !document.contentExternalized {
            prepareContent()
            return
        }
        guard presentsNavigationChrome else { return }
        if loadedBody != nil {
            prepareContent()
            return
        }
        let docId = document.id
        Task { @MainActor in
            let text = await Task.detached {
                DocumentStore.readExternalizedBodyInBackground(id: docId)
            }.value
            guard docId == document.id else { return }
            loadedBody = text
            prepareContent()
        }
    }

    private func prepareContent() {
        useMarkdown = document.isLikelyMarkdown
        if useMarkdown {
            cachedBlocks = MarkdownBlockParser.parse(readerSourceText)
            plainSegments = []
        } else {
            cachedBlocks = []
            plainSegments = PlainTextParagraphs.segments(from: readerSourceText)
        }
    }

    private var speechPlainText: String {
        if useMarkdown, !cachedBlocks.isEmpty {
            return MarkdownBlockParser.plainText(from: cachedBlocks)
        }
        return plainSegments.map(\.text).joined(separator: "\n")
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        let baseSize = store.readingPreferences.fontSize
        let textColor = store.readingPreferences.textColor
        let secondary = store.readingPreferences.secondaryTextColor
        let quoteTint = store.readingPreferences.accentQuoteColor

        switch block.kind {
        case let .heading(level, text):
            Text(text)
                .font(ReaderTypography.bodyFont(size: headingSize(level: level, base: baseSize), weight: .bold))
                .foregroundStyle(textColor)
                .padding(.top, level <= 2 ? 8 : 4)

        case let .paragraph(lines):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(InlineMarkdownFormatter.attributedLine(
                        line,
                        baseFontSize: CGFloat(baseSize),
                        textColor: textColor,
                        secondaryColor: secondary
                    ))
                    .lineSpacing(store.readingPreferences.lineSpacing)
                    .ifPoetryLineAccessibility(document.category == .poetry, line: line)
                }
            }

        case let .blockquote(lines):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(quoteTint)
                            .frame(width: 3)
                        Text(InlineMarkdownFormatter.attributedLine(
                            line,
                            baseFontSize: CGFloat(baseSize),
                            textColor: textColor,
                            secondaryColor: secondary
                        ))
                        .lineSpacing(store.readingPreferences.lineSpacing)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(quoteTint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        case let .bullet(items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .foregroundStyle(secondary)
                        Text(InlineMarkdownFormatter.attributedLine(
                            item,
                            baseFontSize: CGFloat(baseSize),
                            textColor: textColor,
                            secondaryColor: secondary
                        ))
                        .lineSpacing(store.readingPreferences.lineSpacing)
                    }
                }
            }

        case let .ordered(items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(idx + 1).")
                            .foregroundStyle(secondary)
                            .font(ReaderTypography.bodyFont(size: baseSize, weight: .medium))
                        Text(InlineMarkdownFormatter.attributedLine(
                            item,
                            baseFontSize: CGFloat(baseSize),
                            textColor: textColor,
                            secondaryColor: secondary
                        ))
                        .lineSpacing(store.readingPreferences.lineSpacing)
                    }
                }
            }

        case .horizontalRule:
            Divider()
                .background(secondary.opacity(0.35))
                .padding(.vertical, 8)

        case let .noteSection(lines):
            let expanded = expandedNoteBlockIds.contains(block.id)
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    if expandedNoteBlockIds.contains(block.id) {
                        expandedNoteBlockIds.remove(block.id)
                    } else {
                        expandedNoteBlockIds.insert(block.id)
                    }
                } label: {
                    HStack {
                        Text("注释")
                            .font(ReaderTypography.bodyFont(size: CGFloat(baseSize) * 0.92, weight: .semibold))
                            .foregroundStyle(secondary)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                if expanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(InlineMarkdownFormatter.attributedLine(
                                line,
                                baseFontSize: CGFloat(baseSize) * 0.94,
                                textColor: secondary,
                                secondaryColor: secondary.opacity(0.9)
                            ))
                            .lineSpacing(store.readingPreferences.lineSpacing * 0.85)
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(quoteTint.opacity(0.35), lineWidth: 1)
                    )
                }
            }
            .padding(.top, 4)
        }
    }

    private func headingSize(level: Int, base: Double) -> Double {
        switch level {
        case 1: return min(base + 8, 32)
        case 2: return min(base + 4, 28)
        case 3: return min(base + 2, 25)
        default: return min(base + 1, 23)
        }
    }

    private struct TOCEntry {
        let level: Int
        let title: String
        let block: MarkdownBlock
    }

    private func tocEntries(from blocks: [MarkdownBlock]) -> [TOCEntry] {
        blocks.compactMap { b in
            guard case let .heading(level, text) = b.kind else { return nil }
            if document.isBundledAnthology {
                if level == 1 { return nil }
                if text == "注释" { return nil }
                return TOCEntry(level: max(1, level - 1), title: text, block: b)
            }
            return TOCEntry(level: level, title: text, block: b)
        }
    }

    private var approximateScrollOffset: CGFloat {
        max(0, -scrollContentMinY)
    }

    private func visibleBlockId(blocks: [MarkdownBlock]) -> UUID? {
        guard !blocks.isEmpty else { return nil }
        let y0 = approximateScrollOffset
        let y1 = y0 + viewportHeight * 0.35
        var best: (UUID, CGFloat)?
        for b in blocks {
            guard let r = blockFrames[b.id] else { continue }
            let visibleTop = max(r.minY, y0)
            let visibleBottom = min(r.maxY, y1)
            let overlap = visibleBottom - visibleTop
            if overlap > 0 {
                let centerDist = abs(r.midY - (y0 + viewportHeight * 0.2))
                if best == nil || centerDist < best!.1 {
                    best = (b.id, centerDist)
                }
            }
        }
        return best?.0 ?? blocks.first?.id
    }

    private func utf16ForBlock(_ block: MarkdownBlock) -> Int? {
        block.utf16StartOffset(in: readerSourceText)
    }

    private func blockContainingUTF16(_ utf16: Int, blocks: [MarkdownBlock]) -> MarkdownBlock? {
        let source = readerSourceText
        let total = source.utf16.count
        let pairs: [(MarkdownBlock, Int)] = blocks.compactMap { b in
            guard let s = b.utf16StartOffset(in: source) else { return nil }
            return (b, s)
        }.sorted { $0.1 < $1.1 }

        for (i, pair) in pairs.enumerated() {
            let end = i + 1 < pairs.count ? pairs[i + 1].1 : total
            if utf16 >= pair.1 && utf16 < end {
                return pair.0
            }
        }
        return pairs.last?.0
    }

    private func currentProgressUTF16(blocks: [MarkdownBlock]) -> Int? {
        guard let id = visibleBlockId(blocks: blocks),
              let b = blocks.first(where: { $0.id == id }) else { return nil }
        return utf16ForBlock(b)
    }

    private func scheduleProgressSave(blocks: [MarkdownBlock]) {
        progressSaveTask?.cancel()
        progressSaveTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            if let u = currentProgressUTF16(blocks: blocks) {
                store.setReadingProgress(documentId: document.id, utf16Offset: u)
            }
        }
    }

    private func restoreScrollIfNeeded(proxy: ScrollViewProxy, blocks: [MarkdownBlock]) {
        guard let target = store.progressUTF16Offset(for: document.id) else { return }
        guard let block = blockContainingUTF16(target, blocks: blocks) else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(block.id, anchor: .top)
        }
    }

}

private extension View {
    @ViewBuilder
    func ifPoetryLineAccessibility(_ enabled: Bool, line: String) -> some View {
        if enabled {
            let plain = InlineMarkdownFormatter.accessibilityLineDescription(line)
            if !plain.isEmpty {
                accessibilityLabel(plain)
            } else {
                self
            }
        } else {
            self
        }
    }
}

/// iOS 18+ can show a transient empty nav bar / overlay when `navigationTitle` is empty during pager transitions.
/// Pager siblings use a single-space system title plus a custom `.principal` title (see commit 466fc85).
private struct ReaderBarTitleModifier: ViewModifier {
    let title: String
    let useToolbarPrincipal: Bool
    @EnvironmentObject private var store: DocumentStore

    func body(content: Content) -> some View {
        if useToolbarPrincipal {
            content
                .navigationTitle(" ")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(store.readingPreferences.textColor)
                            .lineLimit(1)
                    }
                }
        } else {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Search sheet

private struct ReaderSearchSheet: View {
    let blocks: [MarkdownBlock]
    @Binding var query: String
    var onSelect: (UUID) -> Void

    @EnvironmentObject private var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    private var results: [(block: MarkdownBlock, snippet: String)] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 1 else { return [] }
        var out: [(MarkdownBlock, String)] = []
        for b in blocks {
            let lines = b.plainTextLines()
            for line in lines where line.localizedCaseInsensitiveContains(q) {
                out.append((b, line))
                break
            }
        }
        return out
    }

    var body: some View {
        List {
            Section {
                TextField("输入关键词", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("在当前文档中搜索全文。")
                    .foregroundStyle(.secondary)
            } else if results.isEmpty {
                Text("无匹配结果")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results, id: \.block.id) { row in
                    Button {
                        onSelect(row.block.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.snippet)
                                .lineLimit(3)
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
                Button("完成") { dismiss() }
            }
        }
    }
}
