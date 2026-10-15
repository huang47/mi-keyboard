import SwiftUI

@main
struct BoshiamyApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    private let table: CodeTable? = {
        #if DEBUG
        if let fixture = UITestFixtures.table { return fixture }
        #endif
        return try? TableStore.bundled()
    }()
    @State private var practice = ""
    private let accent = Color(red: 0.68, green: 0.31, blue: 0.16)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("讓熟悉的字碼，\n回到你的 iPhone。")
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                            Text("離線輸入 · 內建字碼表 · 無需完整取用")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "keyboard")
                            .font(.system(size: 28)).foregroundStyle(accent)
                            .padding(12).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Label(table == nil ? "內建字碼表無法載入" : "字碼表已就緒", systemImage: table == nil ? "exclamationmark.triangle" : "checkmark.circle.fill")
                            .font(.headline)
                        if let table = table {
                            Text(table.name).font(.subheadline).lineLimit(2)
                            Text("\(table.entries.count) 組字碼 · \(table.characterCount) 個候選項目")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .accessibilityIdentifier("table-count")
                        } else {
                            Text("請更新或重新安裝 App，以重新取得內建字碼表。")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text("更新 App，即可更新內建字表。")
                            .font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("bundled-table-updates")
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("啟用鍵盤").font(.title3.weight(.semibold))
                        instruction("1", "開啟設定 → 一般 → 鍵盤 → 鍵盤")
                        instruction("2", "加入新鍵盤，選擇「米鍵盤」")
                        instruction("3", "打字時長按地球圖示，切換到米鍵盤")
                        Text("地球圖示可切換系統鍵盤，長按可選 English。下一個鍵盤由 iOS 決定；只保留 English 與米鍵盤時，切換最直接。")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("開啟 App 設定") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }.font(.subheadline).tint(accent)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("試打一段").font(.title3.weight(.semibold))
                        Text("點選輸入框，切換到米鍵盤試打。空白選第一個候選字，候選列可左右滑動。")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("同音查詢：中文模式長按 9（'），輸入已知同音字的字碼，再按空白或點候選。例如 MNFO 選「瞎」，再選「蝦」。刪除可返回字碼。")
                            .font(.footnote).foregroundStyle(.secondary)
                        TextEditor(text: $practice)
                            .frame(height: 120).padding(10)
                            .scrollContentBackground(.hidden)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("practice-editor")
                        NavigationLink("開啟 App 內鍵盤練習") {
                            PracticeView(table: table)
                        }.tint(accent).accessibilityIdentifier("open-practice")
                    }
                    Text("輸入內容不會儲存或上傳。字碼表隨 App 提供。密碼欄位與部分 App 會由 iOS 改用系統鍵盤。\n\n本專案為獨立鍵盤工具，內建 Fcitx5 社群字表，亦非行易官方產品。")
                        .font(.footnote).foregroundStyle(.secondary)
                    NavigationLink("隱私權政策") { PrivacyPolicyView() }
                        .tint(accent).accessibilityIdentifier("open-privacy-policy")
                }.padding(24).frame(maxWidth: 650)
                    .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("米鍵盤")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func instruction(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.caption.weight(.bold)).foregroundStyle(accent)
                .frame(width: 24, height: 24).background(accent.opacity(0.1), in: Circle())
            Text(text).font(.subheadline).padding(.top, 3)
        }
    }


}
