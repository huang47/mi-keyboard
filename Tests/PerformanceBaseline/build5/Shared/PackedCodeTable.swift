import Foundation

/// Build-time dictionary representation; imported tables retain the version-1 JSON format.
enum PackedCodeTable {
    static let magic = Array("BSMY1".utf8)

    static func decode(_ data: Data) throws -> CodeTable {
        guard data.count <= 64 * 1024 * 1024 else { throw TableError.fileTooLarge }
        return try data.withUnsafeBytes { bytes in
            var reader = Reader(bytes: bytes)
            guard try reader.take(magic.count).elementsEqual(magic) else { throw TableError.invalidTable }
            let count = try reader.integer32()
            let nameLength = try reader.integer32()
            let name = try reader.text(length: nameLength)
            guard count > 0, count <= 300_000, count <= reader.remaining / 9 else { throw TableError.invalidTable }
            var entries: [String: [String]] = [:]
            entries.reserveCapacity(count)
            var candidates = 0
            for _ in 0..<count {
                let codeLength = Int(try reader.take(1)[0])
                guard (1...16).contains(codeLength) else { throw TableError.invalidTable }
                let code = try reader.text(length: codeLength)
                let wordCount = try reader.integer16()
                candidates += wordCount
                guard (1...1000).contains(wordCount), candidates <= 500_000 else { throw TableError.invalidTable }
                var words: [String] = []
                words.reserveCapacity(wordCount)
                for _ in 0..<wordCount {
                    let length = try reader.integer32()
                    guard length > 0 else { throw TableError.invalidTable }
                    words.append(try reader.text(length: length))
                }
                entries[code] = words
            }
            guard reader.remaining == 0, entries.count == count else { throw TableError.invalidTable }
            let table = CodeTable(name: name, entries: entries)
            try table.validate()
            return table
        }
    }

    private struct Reader {
        let bytes: UnsafeRawBufferPointer
        private var offset = 0
        var remaining: Int { bytes.count - offset }

        init(bytes: UnsafeRawBufferPointer) { self.bytes = bytes }

        mutating func take(_ length: Int) throws -> UnsafeRawBufferPointer {
            guard length >= 0, length <= remaining else { throw TableError.invalidTable }
            defer { offset += length }
            return UnsafeRawBufferPointer(rebasing: bytes[offset..<(offset + length)])
        }

        mutating func integer16() throws -> Int {
            Int(try take(2).loadUnaligned(as: UInt16.self).littleEndian)
        }

        mutating func integer32() throws -> Int {
            Int(try take(4).loadUnaligned(as: UInt32.self).littleEndian)
        }

        mutating func text(length: Int) throws -> String {
            let raw = try take(length)
            let text = String(decoding: raw, as: UTF8.self)
            guard text.utf8.elementsEqual(raw) else { throw TableError.invalidEncoding }
            return text
        }
    }
}
