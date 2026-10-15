import Foundation

struct CodeTable: Codable, Equatable {
    static let schemaVersion = 1
    let version: Int
    let name: String
    let entries: [String: [String]]
    let characterCount: Int
    let maximumCodeLength: Int
    private let valid: Bool

    private enum CodingKeys: String, CodingKey { case version, name, entries }

    init(name: String, entries: [String: [String]]) {
        self.init(version: Self.schemaVersion, name: name, entries: entries)
    }

    private init(version: Int, name: String, entries: [String: [String]]) {
        self.version = version
        self.name = name
        self.entries = entries
        self.characterCount = entries.values.reduce(0) { $0 + $1.count }
        self.maximumCodeLength = entries.keys.lazy.map(\.count).max() ?? 4
        self.valid = version == Self.schemaVersion && !entries.isEmpty &&
            entries.count <= 300_000 && self.characterCount <= 500_000 &&
            entries.allSatisfy { code, words in
                Self.isValidCode(code) && !words.isEmpty && words.count <= 1000 &&
                words.allSatisfy { !$0.isEmpty && ($0.utf8.count <= 128 || $0.count <= 128) && !$0.utf8.contains(10) }
            }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(version: try container.decode(Int.self, forKey: .version),
                  name: try container.decode(String.self, forKey: .name),
                  entries: try container.decode([String: [String]].self, forKey: .entries))
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
    case invalidTable, invalidEncoding, fileTooLarge, missingSection, unsupportedRime, tooManyEntries
    case invalidLine(Int)

    var errorDescription: String? {
        switch self {
        case .invalidTable: return "字碼表內容或版本不支援。原有字碼表未變更。"
        case .invalidEncoding: return "請使用 UTF-8 編碼的字碼表。"
        case .fileTooLarge: return "檔案超過 20 MB，請匯入較小的字碼表。"
        case .missingSection: return "CIN 檔缺少完整的 %chardef begin / end 區段。"
        case .unsupportedRime: return "請匯入獨立的 Rime 字典；不支援 import_tables、編碼含空格或複雜 YAML 欄位。"
        case .tooManyEntries: return "字碼表項目過多。"
        case .invalidLine(let line): return "第 \(line) 行格式不支援。字碼須為 a–z、逗號、句點、單引號或方括號，最長 16 碼。"
        }
    }
}

enum TableParser {
    static let maximumBytes = 20 * 1024 * 1024

    static func parse(_ data: Data, fileName: String) throws -> CodeTable {
        guard data.count <= maximumBytes else { throw TableError.fileTooLarge }
        guard let source = String(data: data, encoding: .utf8) else { throw TableError.invalidEncoding }
        let lines = source.replacingOccurrences(of: "\u{FEFF}", with: "")
            .components(separatedBy: .newlines)
        let cin = fileName.lowercased().hasSuffix(".cin")
        let rime = fileName.lowercased().hasSuffix(".yaml")
        var entries: [String: [String]] = [:]
        var seen: [String: Set<String>] = [:]
        var count = 0
        var inCharacters = !cin && !rime
        var cinStarted = false
        var cinEnded = false
        var columns = ["text", "code", "weight"]
        var rimeStarted = false
        var rimeEnded = false
        var readingColumns = false

        for (offset, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if cin && line.hasPrefix("%") {
                let lower = line.lowercased()
                if lower == "%chardef begin" {
                    guard !cinStarted else { throw TableError.invalidLine(offset + 1) }
                    cinStarted = true; inCharacters = true; continue
                }
                if lower == "%chardef end" {
                    guard cinStarted, !cinEnded else { throw TableError.missingSection }
                    cinEnded = true; inCharacters = false; continue
                }
            }
            if rime && !rimeEnded {
                if line == "---" { rimeStarted = true; continue }
                if line == "..." {
                    guard rimeStarted, columns.contains("text"), columns.contains("code") else {
                        throw TableError.unsupportedRime
                    }
                    rimeEnded = true; inCharacters = true; continue
                }
                if line.hasPrefix("import_tables:") { throw TableError.unsupportedRime }
                if line.hasPrefix("columns:") {
                    let value = String(line.dropFirst("columns:".count)).trimmingCharacters(in: .whitespaces)
                    if value.isEmpty { columns = []; readingColumns = true }
                    else if value.hasPrefix("["), value.hasSuffix("]") {
                        columns = value.dropFirst().dropLast().split(separator: ",").map {
                            $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                        }
                    } else { throw TableError.unsupportedRime }
                    continue
                }
                if readingColumns && line.hasPrefix("- ") {
                    columns.append(String(line.dropFirst(2)).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")))
                    continue
                }
                readingColumns = false
                continue
            }
            guard inCharacters else { continue }
            let code: String
            let word: String
            if rime {
                let fields = raw.components(separatedBy: "\t")
                guard let codeIndex = columns.firstIndex(of: "code"),
                      let textIndex = columns.firstIndex(of: "text"),
                      fields.count > max(codeIndex, textIndex) else {
                    throw TableError.invalidLine(offset + 1)
                }
                code = fields[codeIndex].trimmingCharacters(in: .whitespaces).lowercased()
                word = fields[textIndex].trimmingCharacters(in: .whitespaces)
            } else {
                let fields = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
                guard fields.count == 2 else { throw TableError.invalidLine(offset + 1) }
                code = fields[0].lowercased()
                word = fields[1].trimmingCharacters(in: .whitespaces)
            }
            guard CodeTable.isValidCode(code), !word.isEmpty, word.count <= 128 else {
                throw TableError.invalidLine(offset + 1)
            }
            let unique: Bool
            if let words = entries[code] {
                if words.count < 8 { unique = !words.contains(word) }
                else {
                    if seen[code] == nil { seen[code] = Set(words) }
                    unique = seen[code, default: []].insert(word).inserted
                }
            } else { unique = true }
            if unique {
                entries[code, default: []].append(word)
                count += 1
                guard count <= 500_000, entries[code]!.count <= 1000 else { throw TableError.tooManyEntries }
            }
        }
        if cin && (!cinStarted || !cinEnded) { throw TableError.missingSection }
        if rime && !rimeEnded { throw TableError.unsupportedRime }
        let table = CodeTable(name: fileName, entries: entries)
        try table.validate()
        return table
    }
}
