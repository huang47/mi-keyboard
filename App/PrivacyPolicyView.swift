import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("更新日期：2026 年 10 月 15 日").font(.footnote).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Text("輸入內容").font(.headline)
                    Text("米鍵盤僅在裝置上處理字碼與選字。輸入文字只用來送至您目前使用的 App；米鍵盤不儲存輸入紀錄，也不將輸入內容上傳至開發者、伺服器或分析服務。您正在使用的其他 App 如何處理送入文字，依該 App 的隱私權政策而定。").accessibilityIdentifier("privacy-section-0")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("內建字碼表").font(.headline)
                    Text("字碼表隨 App 提供，所有查字與同音查詢均在裝置上完成。更新 App 即可取得隨版本附帶的字碼表；不提供外部字表匯入、帳號、雲端同步或遠端上傳。").accessibilityIdentifier("privacy-section-1")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("權限與第三方服務").font(.headline)
                    Text("鍵盤不要求「允許完整取用」。App 不使用廣告、分析 SDK、追蹤或剪貼簿收集功能，也不要求相機、麥克風、聯絡人或位置存取。").accessibilityIdentifier("privacy-section-2")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("資料保留與刪除").font(.headline)
                    Text("App 內的試打文字只在目前畫面記憶體中使用，不寫入輸入紀錄。App 不儲存自訂字表，也不讀取先前版本匯入的字表。移除 App 可清除其本機資料。").accessibilityIdentifier("privacy-section-3")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("政策範圍與支援").font(.headline)
                    Text("本政策適用於米鍵盤主 App 與鍵盤擴充。開發者為 ShihChi Huang。如需支援或對隱私權有疑問，請使用 App Store 產品頁的「App 支援」連結。").accessibilityIdentifier("privacy-section-4")
                }
            }
            .padding(24).frame(maxWidth: 650, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("隱私權政策").navigationBarTitleDisplayMode(.inline)
    }
}
