import SwiftUI
import UniformTypeIdentifiers

struct SettingsPanel: View {
    @EnvironmentObject private var store: DocumentStore
    @Binding var preferences: ReadingPreferences
    /// When true, flush debounced preference disk write on dismiss.
    var flushPreferencesOnDismiss: Bool = false

    @State private var showExportShare = false
    @State private var exportShareURL: URL?
    @State private var showImportBackup = false
    @State private var backupAlert: String?

    var body: some View {
        Form {
            Section("字体") {
                HStack {
                    Text("字号")
                    Slider(value: $preferences.fontSize, in: 14...34, step: 1)
                    Text("\(Int(preferences.fontSize))")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("行距")
                    Slider(value: $preferences.lineSpacing, in: 2...16, step: 1)
                    Text("\(Int(preferences.lineSpacing))")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("段间距")
                    Slider(value: $preferences.readerBlockSpacing, in: 4...28, step: 1)
                    Text("\(Int(preferences.readerBlockSpacing))")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("左右边距")
                    Slider(value: $preferences.readerHorizontalPadding, in: 8...40, step: 1)
                    Text("\(Int(preferences.readerHorizontalPadding))")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("栏宽上限")
                    Slider(value: $preferences.readerMaxColumnWidth, in: 0...720, step: 20)
                    Text(preferences.readerMaxColumnWidth < 10 ? "铺满" : "\(Int(preferences.readerMaxColumnWidth))")
                        .foregroundStyle(.secondary)
                }
            }

            Section("背景与文字") {
                Toggle("跟随系统外观", isOn: $preferences.followSystemAppearance)
                Toggle("夜间自动深色（22:00–07:00）", isOn: $preferences.autoDarkAtNight)
                    .disabled(preferences.followSystemAppearance)
                Picker("阅读主题", selection: $preferences.theme) {
                    ForEach(ReadingPreferences.Theme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(preferences.followSystemAppearance)
                Toggle("护眼偏暖（略深、略黄）", isOn: $preferences.sepiaWarmTint)
                    .disabled(preferences.theme != .sepia)
            }

            Section("数据") {
                Button("导出备份（JSON）") {
                    do {
                        let data = try store.exportBackupData()
                        let name = "MaozedongReader-backup-\(Int(Date().timeIntervalSince1970)).json"
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                        try data.write(to: url, options: .atomic)
                        exportShareURL = url
                        showExportShare = true
                    } catch {
                        backupAlert = "导出失败：\(error.localizedDescription)"
                    }
                }
                Button("从备份恢复…") {
                    showImportBackup = true
                }
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
        .fileImporter(
            isPresented: $showImportBackup,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            do {
                let urls = try result.get()
                guard let url = urls.first else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                try store.importBackup(data: data)
                backupAlert = "已从备份恢复。"
            } catch {
                backupAlert = "恢复失败：\(error.localizedDescription)"
            }
        }
        .alert("备份", isPresented: Binding(
            get: { backupAlert != nil },
            set: { if !$0 { backupAlert = nil } }
        )) {
            Button("好") { backupAlert = nil }
        } message: {
            Text(backupAlert ?? "")
        }
        .onDisappear {
            if flushPreferencesOnDismiss {
                store.flushReadingPreferencesToDisk()
            }
        }
    }
}
