import SwiftUI

struct PracticeView: View {
    let table: CodeTable?
    @State private var text = ""
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    var body: some View {
        VStack(alignment: .leading, spacing: verticalSizeClass == .compact ? 4 : 16) {
            if verticalSizeClass != .compact {
                Text("這裡使用與系統鍵盤相同的輸入引擎；點地球可切換中英文練習。")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
            }
            ScrollView {
                Text(text.isEmpty ? "輸入字碼，點選候選字…" : text)
                    .font(.title3).frame(maxWidth: .infinity, alignment: .leading)
                    .padding().accessibilityIdentifier("practice-output")
            }
            KeyboardPreview(table: table, text: $text, compact: verticalSizeClass == .compact)
                .ignoresSafeArea(.container, edges: .horizontal)
        }
        .padding(.top, verticalSizeClass == .compact ? 0 : 16)
        .navigationTitle("鍵盤練習").navigationBarTitleDisplayMode(.inline)
    }
}

struct KeyboardPreview: UIViewRepresentable {
    let table: CodeTable?
    @Binding var text: String
    var compact: Bool
    func makeUIView(context: Context) -> KeyboardView {
        let keyboard = KeyboardView()
        keyboard.load(table: table)
        keyboard.onOutput = { output in
            switch output {
            case .insert(let value): text += value
            case .deleteBackward: if !text.isEmpty { text.removeLast() }
            case .none: break
            }
        }
        return keyboard
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: KeyboardView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return CGSize(width: width, height: KeyboardView.preferredHeight(width: width, compact: compact))
    }
    func updateUIView(_ uiView: KeyboardView, context: Context) {}
}
