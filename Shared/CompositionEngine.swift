import Foundation

/// Composition remains local until the user chooses a candidate.
struct CompositionEngine {
    enum Mode: Equatable { case chinese, english }
    enum Output: Equatable { case insert(String), deleteBackward, none }

    private(set) var code = ""
    private(set) var mode: Mode = .chinese
    private(set) var hint: String?
    private enum Query {
        case none
        case seed
        case resolved(seedCode: String, words: [String])
    }
    private var query = Query.none
    var isHomophoneQuery: Bool {
        if case .none = query { return false }
        return true
    }
    private let homophones: HomophoneTable?
    var table: CodeTable? {
        didSet { maximumCodeLength = table?.maximumCodeLength ?? 4 }
    }
    private(set) var maximumCodeLength = 4

    init(table: CodeTable? = nil, homophones: HomophoneTable? = nil) {
        self.table = table
        self.homophones = homophones
        self.maximumCodeLength = table?.maximumCodeLength ?? 4
    }

    // Composition codes are normalized by type(_:), so look them up directly.
    var candidates: [String] {
        if case .resolved(_, let words) = query { return words }
        return table?.entries[isHomophoneQuery ? String(code.dropFirst()) : code] ?? []
    }

    mutating func type(_ key: String) -> Output {
        hint = nil
        guard mode == .chinese else { return .insert(key) }
        guard table != nil else { hint = "內建字碼表無法載入，請更新 App"; return .none }
        if case .resolved = query {
            hint = "請選同音字；刪除可返回原字碼"; return .none
        }
        if code.isEmpty && key == "'" {
            query = .seed
            code = "'"
            hint = "同音查詢：輸入已知同音字的字碼"
            return .none
        }
        guard code.count < maximumCodeLength + (isHomophoneQuery ? 1 : 0) else {
            hint = "已達最長字碼，請選字或刪除"; return .none
        }
        let next = code + key.lowercased()
        guard CodeTable.isValidCode(isHomophoneQuery ? String(next.dropFirst()) : next) else { return .none }
        code = next
        return .none
    }

    mutating func choose(_ index: Int) -> Output {
        let words = candidates
        guard words.indices.contains(index) else { return .none }
        let word = words[index]
        if case .seed = query {
            guard let sounds = homophones ?? HomophoneTable.bundled else {
                hint = "同音字資料無法載入；刪除可修改字碼"; return .none
            }
            let matches = sounds.candidates(for: word)
            guard !matches.isEmpty else {
                hint = "沒有這個字的讀音資料；請改用另一個同音字"; return .none
            }
            query = .resolved(seedCode: code, words: matches)
            code = "'" + word
            hint = "同音字：\(word)；選字送出，刪除返回"
            return .none
        }
        reset()
        return .insert(word)
    }

    mutating func space() -> Output {
        if code.isEmpty { return .insert(" ") }
        if !candidates.isEmpty { return choose(0) }
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
        if case .resolved(let seedCode, _) = query {
            code = seedCode
            query = .seed
            return .none
        }
        code.removeLast()
        if code.isEmpty { query = .none }
        return .none
    }

    mutating func insertLiteral(_ text: String) -> Output {
        guard code.isEmpty else {
            if case .seed = query {
                hint = "請先選查詢字，再選同音字"; return .none
            }
            guard let first = candidates.first else {
                hint = "請先修改字碼或長按字碼送出英文"; return .none
            }
            reset()
            return .insert(first + text)
        }
        return .insert(text)
    }

    mutating func toggleMode() -> Output {
        if case .seed = query {
            hint = "請先完成同音查詢，或刪除字碼取消"; return .none
        }
        if !code.isEmpty && candidates.isEmpty {
            hint = "請先修改字碼或長按字碼送出英文"; return .none
        }
        let output: Output = code.isEmpty ? .none : choose(0)
        mode = mode == .chinese ? .english : .chinese
        hint = nil
        return output
    }

    mutating func reset() {
        code = ""; hint = nil
        query = .none
    }
}
