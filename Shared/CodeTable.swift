import Foundation

struct CodeTable: Equatable {
    let name: String
    let entries: [String: [String]]
    let characterCount: Int
    let maximumCodeLength: Int
    private let valid: Bool

    init(name: String, entries: [String: [String]]) {
        self.name = name
        self.entries = entries
        self.characterCount = entries.values.reduce(0) { $0 + $1.count }
        self.maximumCodeLength = entries.keys.lazy.map(\.count).max() ?? 4
        self.valid = !entries.isEmpty &&
            entries.count <= 300_000 && self.characterCount <= 500_000 &&
            entries.allSatisfy { code, words in
                Self.isValidCode(code) && !words.isEmpty && words.count <= 1000 &&
                words.allSatisfy { !$0.isEmpty && ($0.utf8.count <= 128 || $0.count <= 128) && !$0.utf8.contains(10) }
            }
    }

    func candidates(for code: String) -> [String] { entries[code.lowercased()] ?? [] }

    func validate() throws {
        guard valid else { throw TableError.invalidTable }
    }

    static func isValidCode(_ code: String) -> Bool {
        !code.isEmpty && code.utf8.count <= 16 &&
        code.utf8.allSatisfy { (97...122).contains($0) || [39, 44, 46, 91, 93].contains($0) }
    }
}

enum TableError: LocalizedError {
    case invalidTable, invalidEncoding, fileTooLarge

    var errorDescription: String? {
        "內建字碼表無法載入。請更新或重新安裝 App。"
    }
}
