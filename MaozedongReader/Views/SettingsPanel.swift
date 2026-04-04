import SwiftUI

struct SettingsPanel: View {
    @Binding var preferences: ReadingPreferences
    var onSave: (() -> Void)?

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
            }

            Section("背景与文字") {
                Picker("阅读主题", selection: $preferences.theme) {
                    ForEach(ReadingPreferences.Theme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .onChange(of: preferences) { _, _ in
            onSave?()
        }
    }
}
