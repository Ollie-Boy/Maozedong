# Maozedong Reader (iPhone)

一个基于 **SwiftUI** 的 iPhone 阅读 App 原型，面向“著作阅读”场景。

核心目标：
- 阅读文本（诗词、语录、文章等）
- 支持系统语音朗读
- 支持字体大小、行距、背景主题调整
- 支持导入本地文件（`txt` / `md`）

> 说明：当前仓库提供的是可直接放入 Xcode 工程的源码目录（`MaozedongReader/`）。

## 当前功能

1. **书库页（Library）**
   - 展示已导入文档
   - 内置一个示例文本（首次启动自动生成）
   - 支持删除文档

2. **阅读页（Reader）**
   - 阅读正文
   - 一键朗读/停止朗读（`AVSpeechSynthesizer`）
   - 阅读设置弹窗（字号、行距、主题）

3. **导入功能**
   - 通过系统文件选择器导入 `txt` / `md`
   - 自动处理常见编码（UTF-8 / UTF-16 / GB18030）
   - 导入后立即加入书库并持久化

4. **持久化**
   - 文档列表与内容本地保存
   - 阅读偏好（字号/行距/主题）本地保存

## 目录结构

```text
MaozedongReader/
  MaozedongReaderApp.swift
  Models/
    DocumentItem.swift
    ReadingPreferences.swift
  Services/
    DocumentStore.swift
    PlainTextFileImporter.swift
    SpeechService.swift
  Views/
    LibraryView.swift
    ReaderView.swift
    SettingsPanel.swift
```

## 如何在 Xcode 运行

1. 打开 Xcode，新建 iOS App（SwiftUI + Swift）。
2. 将本仓库的 `MaozedongReader/` 下所有 `.swift` 文件拖入你的工程 target（勾选 Copy items if needed）。
3. 将 App 入口替换为 `MaozedongReaderApp.swift`（或把其中内容合并到你的 App 入口）。
4. 选择 iPhone 模拟器或真机运行。

## 后续可扩展建议

- 章节目录、收藏与书签、阅读进度
- 全文搜索与高亮
- 更细粒度朗读（段落朗读、语速/音色选择）
- 云端同步（iCloud）
- 导入 PDF / ePub（需额外解析能力）
