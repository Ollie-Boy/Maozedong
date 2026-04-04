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
   - 按内容类型分组展示：**诗词**、**语录**、**文章**（导入时按文件名与篇幅自动推测分类，也可长按或上下文菜单修改）
   - 顶部 **搜索**：在标题与正文中全文检索
   - 可按分组筛选（工具栏「分组」）
   - 左滑删除单篇文档
   - 内置多篇示例（首次启动且书库为空时生成）
   - 额外提供可直接导入的示例 Markdown：`MaozedongReader/SampleContent/` 目录

2. **阅读页（Reader）**
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
  SampleContent/           # 可直接导入的 .md 示例
  Models/
    DocumentItem.swift
    DocumentCategory.swift
    BookmarkEntry.swift
    ReaderStateSnapshot.swift
    ReadingPreferences.swift
  Services/
    BundledSampleImporter.swift
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
2. 在 Xcode 左侧选中 **MaozedongReader** target → **Signing & Capabilities**，将 **Team** 设为你的 Apple ID 团队（真机调试必需；模拟器通常也可直接运行）。
3. 顶部选择 **iPhone 模拟器**（或已连接的真机），按 **⌘R** 运行；断点与控制台调试与常规 iOS 工程相同。

### 手动接入到其他工程（可选）

若你已有自己的 Xcode 工程，仍可将 `MaozedongReader/` 下所有 `.swift` 与 `Assets.xcassets` 拖入 target，并把入口改为 `MaozedongReaderApp.swift`。

内置示例 Markdown 已作为 **Bundle 资源** 打进 App，路径为 `MaozedongReader/SampleContent/*.md`；也可通过「导入」从本机选取其他文件。

## 后续可扩展建议

- 更细粒度朗读（段落朗读、语速/音色选择）
- 云端同步（iCloud）
- 导入 PDF / ePub（需额外解析能力）
