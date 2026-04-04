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

struct ReaderView: View {
    @EnvironmentObject private var store: DocumentStore
    @StateObject private var speechService = SpeechService()

    let document: DocumentItem
    @State private var showingSettings = false
    @State private var showingTOC = false
    @State private var showingSearch = false
    @State private var showingBookmarks = false
    @State private var searchQuery = ""

    @State private var cachedBlocks: [MarkdownBlock] = []
    @State private var plainSegments: [(text: String, utf16Start: Int)] = []
    @State private var useMarkdown = false

    @State private var scrollContentMinY: CGFloat = 0
    @State private var blockFrames: [UUID: CGRect] = [:]
    @State private var viewportHeight: CGFloat = 600

    @State private var scrollToBlockId: UUID?
    @State private var progressSaveTask: Task<Void, Never>?

    private let scrollSpaceName = "readerScroll"

    var body: some View {
        let blocks = displayBlocks
        let headings = tocEntries(from: blocks)

        ZStack {
            store.readingPreferences.backgroundColor
                .ignoresSafeArea()

            GeometryReader { geo in
                Color.clear
                    .onAppear { viewportHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in viewportHeight = h }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        Color.clear
                            .frame(height: 0)
                            .background(
                                GeometryReader { g in
                                    Color.clear.preference(
                                        key: ScrollContentMinYKey.self,
                                        value: g.frame(in: .named(scrollSpaceName)).minY
                                    )
                                }
                            )

                        ForEach(blocks) { item in
                            blockView(item)
                                .id(item.id)
                                .background(
                                    GeometryReader { g in
                                        Color.clear.preference(
                                            key: BlockFramesKey.self,
                                            value: [item.id: g.frame(in: .named(scrollSpaceName))]
                                        )
                                    }
                                )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .coordinateSpace(name: scrollSpaceName)
                .onPreferenceChange(ScrollContentMinYKey.self) { scrollContentMinY = $0 }
                .onPreferenceChange(BlockFramesKey.self) { blockFrames = $0 }
                .onChange(of: scrollContentMinY) { _, _ in scheduleProgressSave(blocks: blocks) }
                .onChange(of: blockFrames) { _, _ in scheduleProgressSave(blocks: blocks) }
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
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingTOC = true
                } label: {
                    Label("目录", systemImage: "list.bullet")
                }

                Button {
                    searchQuery = ""
                    showingSearch = true
                } label: {
                    Label("搜索", systemImage: "magnifyingglass")
                }

                Button {
                    showingBookmarks = true
                } label: {
                    Label("书签", systemImage: "bookmark")
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
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsPanel(preferences: $store.readingPreferences)
                    .navigationTitle("阅读设置")
                    .navigationBarTitleDisplayMode(.inline)
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
                    if headings.isEmpty {
                        Text("本文暂无标题（使用 Markdown 的 # 标题可生成目录）")
                            .foregroundStyle(.secondary)
                    } else {
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
                }
                .navigationTitle("目录")
                .navigationBarTitleDisplayMode(.inline)
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
            }
        }
        .sheet(isPresented: $showingBookmarks) {
            NavigationStack {
                ReaderBookmarksSheet(
                    bookmarks: store.bookmarks(for: document.id),
                    onJump: { offset in
                        jumpToUTF16(offset, blocks: blocks)
                        showingBookmarks = false
                    },
                    onRemove: { ids in
                        store.removeBookmarks(ids: ids)
                    },
                    onAddCurrent: {
                        let utf16 = currentProgressUTF16(blocks: blocks) ?? 0
                        let label = labelForOffset(utf16, blocks: blocks)
                        store.addBookmark(documentId: document.id, utf16Offset: utf16, label: label)
                    }
                )
            }
        }
        .onAppear {
            prepareContent()
        }
        .onChange(of: document.id) { _, _ in
            prepareContent()
        }
        .onChange(of: document.content) { _, _ in
            prepareContent()
        }
        .onDisappear {
            progressSaveTask?.cancel()
            let utf16 = currentProgressUTF16(blocks: blocks) ?? store.progressUTF16Offset(for: document.id) ?? 0
            store.setReadingProgress(documentId: document.id, utf16Offset: utf16)
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

    private func prepareContent() {
        useMarkdown = document.isLikelyMarkdown
        if useMarkdown {
            cachedBlocks = MarkdownBlockParser.parse(document.content)
            plainSegments = []
        } else {
            cachedBlocks = []
            plainSegments = PlainTextParagraphs.segments(from: document.content)
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
                .font(.system(size: headingSize(level: level, base: baseSize), weight: .bold))
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
                            .font(.system(size: CGFloat(baseSize), weight: .medium, design: .rounded))
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
        }
    }

    private func headingSize(level: Int, base: Double) -> Double {
        switch level {
        case 1: return min(base + 10, 34)
        case 2: return min(base + 6, 30)
        case 3: return min(base + 3, 26)
        default: return min(base + 1, 24)
        }
    }

    private struct TOCEntry {
        let level: Int
        let title: String
        let block: MarkdownBlock
    }

    private func tocEntries(from blocks: [MarkdownBlock]) -> [TOCEntry] {
        blocks.compactMap { b in
            if case let .heading(level, text) = b.kind {
                return TOCEntry(level: level, title: text, block: b)
            }
            return nil
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
        block.utf16StartOffset(in: document.content)
    }

    private func blockContainingUTF16(_ utf16: Int, blocks: [MarkdownBlock]) -> MarkdownBlock? {
        let source = document.content
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

    private func jumpToUTF16(_ utf16: Int, blocks: [MarkdownBlock]) {
        if let b = blockContainingUTF16(utf16, blocks: blocks) {
            scrollToBlockId = b.id
        }
    }

    private func labelForOffset(_ utf16: Int, blocks: [MarkdownBlock]) -> String {
        guard let b = blockContainingUTF16(utf16, blocks: blocks) else { return "书签" }
        switch b.kind {
        case let .heading(_, t): return String(t.prefix(48))
        case let .paragraph(ls): return String((ls.first ?? "").prefix(48))
        case let .blockquote(ls): return String((ls.first ?? "").prefix(48))
        case let .bullet(items): return String((items.first ?? "").prefix(48))
        case let .ordered(items): return String((items.first ?? "").prefix(48))
        case .horizontalRule: return "分隔线"
        }
    }
}

// MARK: - Search sheet

private struct ReaderSearchSheet: View {
    let blocks: [MarkdownBlock]
    @Binding var query: String
    var onSelect: (UUID) -> Void

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
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
    }
}

// MARK: - Bookmarks sheet

private struct ReaderBookmarksSheet: View {
    let bookmarks: [BookmarkEntry]
    var onJump: (Int) -> Void
    var onRemove: ([UUID]) -> Void
    var onAddCurrent: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Button("在当前位置添加书签") {
                    onAddCurrent()
                }
            }
            if bookmarks.isEmpty {
                Text("暂无书签")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(bookmarks) { bm in
                    Button {
                        onJump(bm.utf16Offset)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bm.label)
                                .font(.headline)
                            Text(readerBookmarkDateString(bm.createdAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onRemove([bm.id])
                        } label: {
                            Text("删除")
                        }
                    }
                }
            }
        }
        .navigationTitle("书签")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
    }
}

private func readerBookmarkDateString(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .short
    f.locale = Locale(identifier: "zh_CN")
    return f.string(from: d)
}
