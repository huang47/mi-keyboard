import Foundation

/// Decode the app's flat table schema without building a general JSON object tree.
/// Unfamiliar shapes use JSONDecoder, retaining its compatibility and error behavior.
enum TableJSON {
    private enum Unsupported: Error { case shape }

    static func decode(_ data: Data) throws -> CodeTable {
        do {
            return try data.withUnsafeBytes { bytes in
                var reader = Reader(bytes: bytes)
                return try reader.table()
            }
        } catch is Unsupported {
            return try JSONDecoder().decode(CodeTable.self, from: data)
        }
    }

    private struct Reader {
        let bytes: UnsafeRawBufferPointer
        var offset = 0

        mutating func whitespace() {
            while offset < bytes.count {
                switch bytes[offset] {
                case 9, 10, 13, 32: offset += 1
                default: return
                }
            }
        }

        mutating func consume(_ value: UInt8) -> Bool {
            whitespace()
            guard offset < bytes.count, bytes[offset] == value else { return false }
            offset += 1
            return true
        }

        mutating func expect(_ value: UInt8) throws {
            guard consume(value) else { throw Unsupported.shape }
        }

        mutating func string() throws -> String {
            try expect(34)
            let start = offset
            var escaped = false
            while offset < bytes.count {
                let value = bytes[offset]
                if value == 34 {
                    let end = offset
                    offset += 1
                    if escaped {
                        // Delegate escape and surrogate-pair semantics to Foundation.
                        let data = Data(bytes[(start - 1)..<offset])
                        guard let text = try? JSONDecoder().decode(String.self, from: data) else { throw Unsupported.shape }
                        return text
                    }
                    let raw = bytes[start..<end]
                    let text = String(decoding: raw, as: UTF8.self)
                    guard text.utf8.elementsEqual(raw) else { throw Unsupported.shape }
                    return text
                }
                guard value >= 32 else { throw Unsupported.shape }
                if value == 92 { escaped = true; offset += 2 }
                else { offset += 1 }
            }
            throw Unsupported.shape
        }

        mutating func words() throws -> [String] {
            try expect(91)
            var words: [String] = []
            if consume(93) { return words }
            while true {
                words.append(try string())
                if consume(93) { return words }
                try expect(44)
            }
        }

        mutating func entries() throws -> [String: [String]] {
            try expect(123)
            var entries: [String: [String]] = [:]
            entries.reserveCapacity(min(4096, bytes.count / 16))
            if consume(125) { return entries }
            while true {
                let code = try string()
                try expect(58)
                let candidates = try words()
                guard entries.updateValue(candidates, forKey: code) == nil else { throw Unsupported.shape }
                if consume(125) { return entries }
                try expect(44)
            }
        }

        mutating func table() throws -> CodeTable {
            try expect(123)
            var fields = 0
            var name: String?
            var values: [String: [String]]?
            while true {
                let key = try string()
                try expect(58)
                switch key {
                case "version":
                    guard fields & 1 == 0 else { throw Unsupported.shape }
                    try expect(49) // Only version 1 has this fast representation.
                    fields |= 1
                case "name":
                    guard fields & 2 == 0 else { throw Unsupported.shape }
                    name = try string()
                    fields |= 2
                case "entries":
                    guard fields & 4 == 0 else { throw Unsupported.shape }
                    values = try entries()
                    fields |= 4
                default: throw Unsupported.shape
                }
                if consume(125) { break }
                try expect(44)
            }
            whitespace()
            guard offset == bytes.count, fields == 7, let name, let values else { throw Unsupported.shape }
            return CodeTable(name: name, entries: values)
        }
    }
}
