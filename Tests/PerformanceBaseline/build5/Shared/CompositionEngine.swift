import Foundation

/// Composition remains local until the user chooses a candidate.
struct CompositionEngine {
    enum Mode: Equatable { case chinese, english }
    enum Output: Equatable { case insert(String), deleteBackward, none }

    private(set) var code = ""
    private(set) var mode: Mode = .chinese
    private(set) var hint: String?
    var table: CodeTable? {
        didSet { maximumCodeLength = table?.maximumCodeLength ?? 4 }
    }
    private(set) var maximumCodeLength = 4

    init(table: CodeTable? = nil) {
        self.table = table
        self.maximumCodeLength = table?.maximumCodeLength ?? 4
    }

    // Composition codes are normalized by type(_:), so look them up directly.
    var candidates: [String] { table?.entries[code] ?? [] }

    mutating func type(_ key: String) -> Output {
        hint = nil
        guard mode == .chinese else { return .insert(key) }
        guard table != nil else { hint = "請先在米鍵盤 App 匯入字碼表"; return .none }
        guard code.count < maximumCodeLength else {
            hint = "已達最長字碼，請選字或刪除"; return .none
        }
        let next = code + key.lowercased()
        guard CodeTable.isValidCode(next) else { return .none }
        code = next
        return .none
    }

    mutating func choose(_ index: Int) -> Output {
        let words = candidates
        guard words.indices.contains(index) else { return .none }
        let word = words[index]
        reset()
        return .insert(word)
    }

    mutating func space() -> Output {
        if code.isEmpty { return .insert(" ") }
        if let word = candidates.first { reset(); return .insert(word) }
        hint = "沒有對應字，請修改字碼；長按字碼可送出英文"
        return .none
    }

    mutating func literalComposition() -> Output {
        guard !code.isEmpty else { return .none }
        let text = code
        reset()
        return .insert(text)
    }

    mutating func backspace() -> Output {
        hint = nil
        guard !code.isEmpty else { return .deleteBackward }
        code.removeLast()
        return .none
    }

    mutating func insertLiteral(_ text: String) -> Output {
        guard code.isEmpty else {
            guard let first = candidates.first else {
                hint = "請先修改字碼或長按字碼送出英文"; return .none
            }
            reset()
            return .insert(first + text)
        }
        return .insert(text)
    }

    mutating func toggleMode() -> Output {
        if !code.isEmpty && candidates.isEmpty {
            hint = "請先修改字碼或長按字碼送出英文"; return .none
        }
        let output: Output = code.isEmpty ? .none : choose(0)
        mode = mode == .chinese ? .english : .chinese
        hint = nil
        return output
    }

    mutating func reset() { code = ""; hint = nil }
}
