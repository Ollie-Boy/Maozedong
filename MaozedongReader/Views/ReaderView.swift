import SwiftUI

struct ReaderView: View {
    @EnvironmentObject private var store: DocumentStore
    @StateObject private var speechService = SpeechService()

    let document: DocumentItem
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            store.readingPreferences.backgroundColor
                .ignoresSafeArea()

            ScrollView {
                Text(document.content)
                    .font(.system(size: store.readingPreferences.fontSize))
                    .lineSpacing(store.readingPreferences.lineSpacing)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .foregroundStyle(store.readingPreferences.textColor)
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    if speechService.isSpeaking {
                        speechService.stop()
                    } else {
                        speechService.speak(document.content)
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
    }
}
