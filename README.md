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
   - **选集**：首次启动会自动从 GitHub 仓库 [weiyinfu/MaoZeDongAnthology](https://github.com/weiyinfu/MaoZeDongAnthology) 的 **`master` 分支 `src/`** 拉取全部 `.md`（与 README 目录一致）；工具栏 **「同步选集」** 可强制重新下载。选集篇目按文件名三位序号排序，阅读时 **左右滑动** 切换相邻篇
   - 进入 **诗词** 后支持 **左右滑动** 切换相邻篇目（时间顺序）
   - 内置 **毛泽东诗词** 全文（**131 篇**，含「正文 / 分隔线 / 注释」排版），资源为 `Resources/BundledPoetryCorpus_part*.txt`；升级时若内置语料版本变化会替换旧的内置诗词条目
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
  Resources/               # 内置诗词语料（UTF-8 分片 txt）
  Models/
    DocumentItem.swift
    DocumentCategory.swift
    BookmarkEntry.swift
    ReaderStateSnapshot.swift
    ReadingPreferences.swift
  Services/
    BundledSampleImporter.swift
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

### 手动接入到其他工程（可选）

若你已有自己的 Xcode 工程，仍可将 `MaozedongReader/` 下所有 `.swift` 与 `Assets.xcassets` 拖入 target，并把入口改为 `MaozedongReaderApp.swift`。

内置示例 Markdown 已作为 **Bundle 资源** 打进 App，路径为 `MaozedongReader/SampleContent/*.md`；内置诗词语料为 `Resources/BundledPoetryCorpus_part*.txt`（格式见同目录 `README_CORPUS.txt`）。也可通过「导入」从本机选取其他文件。

**版权声明**：应用内网页阅读（马克思主义文库等）仅作链接展示；打包的正文请以权利人许可为准，自行核对后再分发。

### 选集数据源

- 已内置对接 **`https://github.com/weiyinfu/MaoZeDongAnthology`** 的 `src/*.md`（需网络权限）。
- 若上游更换仓库或分支，修改 `RemoteAnthologySync.swift` 中的 `owner` / `repo` / `branch` / `srcPath`，并递增 `DocumentStore.remoteAnthologyBundleVersion` 以触发用户端重新同步。

## 后续可扩展建议

- 更细粒度朗读（段落朗读、语速/音色选择）
- 云端同步（iCloud）
- 导入 PDF / ePub（需额外解析能力）
