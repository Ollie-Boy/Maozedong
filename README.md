# Maozedong Reader (iPhone)

一个基于 **SwiftUI** 的 iPhone 阅读 App 原型，面向“著作阅读”场景。

核心目标：
- 阅读文本（诗词、语录、文章等）
- 支持系统语音朗读
- 支持字体大小、行距、背景主题调整
- 支持导入本地文件（`txt` / `md`）

> 说明：仓库根目录包含 **`MaozedongReader.xcodeproj`**，用 Xcode 直接打开即可在模拟器/真机上 **⌘R 运行与调试**。源码仍在 `MaozedongReader/` 目录下。

## 当前功能

1. **书库页（Library）**
   - 分组：**诗词**、**选集**（可折叠；诗词按年代排序，列表旁显示年份）
   - **选集**：**完全离线**，正文在 `BundledAnthology/*.md`（不含 `目录.md`）；由 `Resources/AnthologyTOC.md` 解析。**书库三级**：卷（`#`）→ 二级分期（`##`，如同一卷下的「抗日战争时期（上/下）」）→ 篇目列表；仅含一个二级分组时省略中间层。**左右滑动** 仅在 **同一二级分组** 内切换相邻篇
   - 进入 **诗词** 后支持 **左右滑动** 切换相邻篇目（时间顺序）
   - 内置 **毛泽东诗词** 全文（**131 篇**），资源为 `Resources/BundledPoetryCorpus_part*.txt`；排版与选集一致：`#` 篇名、`## 正文`、`---`、`## 注释`（注释仅保留首行来源说明）；升级时若内置语料版本变化会替换旧的内置诗词条目
   - **阅读主题**（浅色/深色/护眼）应用于书库、设置与各列表；状态栏随深色主题反色
   - 进入阅读或横向翻页后即显示 **已读**；滚动仍会更新具体阅读位置
   - **App 图标**：`Assets.xcassets/AppIcon.appiconset/AppIcon.png`（红底、金圆、书页色带）；可用 `python3 scripts/generate_app_icon.py` 重新生成
   - 顶部 **搜索**：在标题与正文中全文检索
   - 可按分组筛选（工具栏「分组」）
   - 左滑删除单篇文档
   - 不再内置示例诗词/文章；书库仅含 **内置诗词语料**、**内置选集** 与用户导入文件（升级后会自动清理旧版示例条目）

2. **阅读页（Reader）**
   - 导航栏、底部工具栏与正文同色；横向翻页时 `TabView` 底部区域与主题一致（避免白条割裂）；诗词/选集横向翻页 **不显示** 底部分页圆点
   - **Markdown** 渲染：标题层级、引用块、无序/有序列表、分隔线；行内 `**粗体**` 与 `` `代码` ``
   - **目录**：从 `#` 标题生成大纲并跳转
   - **全文搜索**（当前文档）
   - **书签**：添加、跳转、滑动删除
   - **阅读进度**：按当前可见段落自动保存（UTF-16 偏移），再次打开时恢复位置
   - 一键朗读/停止朗读（`AVSpeechSynthesizer`）
   - 阅读设置（字号、行距、主题）

3. **导入功能**
   - 通过系统文件选择器导入 `txt` / `md`
   - 自动处理常见编码（UTF-8 / UTF-16 / GB18030）
   - 导入后立即加入书库并持久化

4. **持久化**
   - 文档列表与内容本地保存
   - 阅读偏好（字号/行距/主题）本地保存
   - 阅读进度与书签：`reader_state.json`

## 目录结构

```text
MaozedongReader.xcodeproj/   # Xcode 工程（打开此文件）
MaozedongReader/
  MaozedongReaderApp.swift
  Resources/               # 内置诗词语料（UTF-8 分片 txt）、AnthologyTOC.md
  Models/
    DocumentItem.swift
    DocumentCategory.swift
    BookmarkEntry.swift
    ReaderStateSnapshot.swift
    ReadingPreferences.swift
  Services/
    BundledPoetryImporter.swift
    PoetryCorpusParser.swift
    DocumentStore.swift
    PlainTextFileImporter.swift
    PlainTextParagraphs.swift
    MarkdownBlockParser.swift
    InlineMarkdownFormatter.swift
    StableUUID.swift
    SpeechService.swift
  Views/
    LibraryView.swift
    ReaderView.swift
    SettingsPanel.swift
```

## 如何在 Xcode 运行（推荐）

1. 双击打开仓库根目录的 **`MaozedongReader.xcodeproj`**。
2. **模拟器**：工程已对 `iphonesimulator` 使用 **不签名**（`CODE_SIGN_IDENTITY = -`），一般 **无需 Team**、也不会向 Apple 申请新 App ID，直接选模拟器 **⌘R** 即可。
3. **真机**：在 target → **Signing & Capabilities** 选择 **Team**。若提示 **App ID 数量已达 7 天上限**，不要新建 Bundle ID：把 **Bundle Identifier** 改成你账号里**已有**的任意 App ID（或等配额恢复后再用自动管理签名）。
4. 顶部选择 **iPhone 模拟器** 或真机，按 **⌘R** 运行；断点与控制台调试与常规 iOS 工程相同。

### 若仍出现 “Communication with Apple failed” / “No profiles …”

- **优先用模拟器**跑通工程（不占用 App ID 配额）。
- **真机**：在 Signing 里勾选 **Automatically manage signing**，**Bundle Identifier** 改为已存在的 ID；或暂时关掉 **Automatically manage signing**，选手动 **Provisioning Profile**（若你有）。
- 默认占位符为 `com.example.MaozedongReader`，极易触发「新建 App ID」；真机调试时请改成你自己的、且未超限的标识符。


### 更新内置选集（离线数据）

1. 同步 `src/*.md` 到 `MaozedongReader/BundledAnthology/`（不要放入 `目录.md`，或同步后删除之）。
2. 将上游 `目录.md` 复制为 `MaozedongReader/Resources/AnthologyTOC.md`（供 `AnthologyTocParser` 解析）。
3. 在 `DocumentStore.swift` 中递增 **`bundledAnthologyVersion`**，以便已安装用户下次启动时替换旧的内置选集条目。
