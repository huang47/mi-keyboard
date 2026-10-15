import XCTest

final class CoreTests: XCTestCase {
    private struct CanonicalTable: Decodable {
        let version: Int
        let name: String
        let entries: [String: [String]]
    }

    private let table = CodeTable(name: "synthetic", entries: ["a": ["甲", "乙"], "ab": ["測試"], ",,": ["，"]])

    func testHomophoneQueryDoesNotCommitSeedAndUsesFullLengthCode() throws {
        let sounds = try XCTUnwrap(HomophoneTable.load(in: Bundle(for: Self.self)))
        let real = try XCTUnwrap(TableStore.bundled(in: Bundle(for: Self.self)))
        var engine = CompositionEngine(table: real, homophones: sounds)
        for key in "'mnfo" { XCTAssertEqual(engine.type(String(key)), .none) }
        XCTAssertEqual(engine.candidates.first, "瞎")
        XCTAssertEqual(engine.space(), .none)
        XCTAssertEqual(engine.code, "'瞎")
        XCTAssertTrue(engine.candidates.contains("蝦"))
        XCTAssertEqual(engine.type("a"), .none)
        let shrimp = try XCTUnwrap(engine.candidates.firstIndex(of: "蝦"))
        XCTAssertEqual(engine.choose(shrimp), .insert("蝦"))
        XCTAssertEqual(engine.code, "")
        XCTAssertFalse(engine.isHomophoneQuery)
        _ = engine.type("h"); _ = engine.type("x")
        XCTAssertEqual(engine.space(), .insert("愛"))
    }

    func testHomophoneBackspaceReturnsToSeedThenCancelsWithoutDeletingHostText() throws {
        let sounds = try XCTUnwrap(HomophoneTable.load(in: Bundle(for: Self.self)))
        var engine = CompositionEngine(table: CodeTable(name: "seed", entries: ["ab": ["音"]]), homophones: sounds)
        for key in "'ab" { _ = engine.type(String(key)) }
        XCTAssertEqual(engine.choose(0), .none)
        XCTAssertEqual(engine.backspace(), .none)
        XCTAssertEqual(engine.code, "'ab")
        XCTAssertEqual(engine.candidates, ["音"])
        XCTAssertEqual(engine.backspace(), .none)
        XCTAssertEqual(engine.code, "'a")
        XCTAssertEqual(engine.backspace(), .none)
        XCTAssertEqual(engine.code, "'")
        XCTAssertEqual(engine.backspace(), .none)
        XCTAssertFalse(engine.isHomophoneQuery)
        XCTAssertEqual(engine.backspace(), .deleteBackward)
    }

    func testHomophonesKeepTonesAndAllPolyphonicReadingsWithoutDuplicates() throws {
        let sounds = try XCTUnwrap(HomophoneTable.load(in: Bundle(for: Self.self)))
        let yin = sounds.candidates(for: "音")
        XCTAssertTrue(yin.contains("因")); XCTAssertTrue(yin.contains("陰"))
        XCTAssertFalse(yin.contains("印")); XCTAssertFalse(yin.contains("銀"))
        let xing = sounds.candidates(for: "行")
        XCTAssertTrue(xing.contains("航")); XCTAssertTrue(xing.contains("型"))
        XCTAssertEqual(Set(xing).count, xing.count)
        XCTAssertEqual(xing.first, "行")
        XCTAssertEqual(sounds.candidates(for: "測試"), [])
        XCTAssertEqual(sounds.candidates(for: "🙂"), [])
    }

    func testUnknownHomophoneSeedsPreserveQueryAndDoNotCommitOnModeOrPunctuation() throws {
        let sounds = try XCTUnwrap(HomophoneTable.load(in: Bundle(for: Self.self)))
        var engine = CompositionEngine(table: CodeTable(name: "seed", entries: ["a": ["🙂", "測試", "音"]]), homophones: sounds)
        for key in "'a" { _ = engine.type(String(key)) }
        XCTAssertEqual(engine.choose(0), .none)
        XCTAssertEqual(engine.choose(1), .none)
        XCTAssertEqual(engine.insertLiteral("！"), .none)
        XCTAssertEqual(engine.toggleMode(), .none)
        XCTAssertEqual(engine.mode, .chinese)
        XCTAssertEqual(engine.code, "'a")
        XCTAssertEqual(engine.choose(2), .none)
        XCTAssertEqual(engine.insertLiteral("！"), .insert("音！"))
        XCTAssertFalse(engine.isHomophoneQuery)
        _ = engine.toggleMode()
        XCTAssertEqual(engine.type("'"), .insert("'"))
        _ = engine.toggleMode()
        _ = engine.type("'")
        XCTAssertEqual(engine.literalComposition(), .insert("'"))
        XCTAssertFalse(engine.isHomophoneQuery)
    }

    func testHomophoneResetAndTableReloadNeverRetainOldCandidates() throws {
        let sounds = try XCTUnwrap(HomophoneTable.load(in: Bundle(for: Self.self)))
        var engine = CompositionEngine(table: CodeTable(name: "seed", entries: ["a": ["音"]]), homophones: sounds)
        for key in "'a" { _ = engine.type(String(key)) }
        _ = engine.space()
        engine.reset()
        engine.table = table
        _ = engine.type("a")
        XCTAssertEqual(engine.candidates, ["甲", "乙"])
        XCTAssertEqual(engine.space(), .insert("甲"))
    }

    func testCompositionIsNotSentUntilUserChooses() {
        var engine = CompositionEngine(table: table)
        XCTAssertEqual(engine.type("a"), .none)
        XCTAssertEqual(engine.candidates, ["甲", "乙"])
        XCTAssertEqual(engine.choose(1), .insert("乙"))
        XCTAssertEqual(engine.code, "")
        XCTAssertEqual(engine.type("a"), .none)
        XCTAssertEqual(engine.type("b"), .none)
        XCTAssertEqual(engine.space(), .insert("測試"))
        XCTAssertEqual(engine.space(), .insert(" "))
    }

    func testInvalidCodeNeverDiscardsInput() {
        var engine = CompositionEngine(table: table)
        _ = engine.type("z")
        XCTAssertEqual(engine.space(), .none)
        XCTAssertEqual(engine.code, "z")
        XCTAssertEqual(engine.insertLiteral("！"), .none)
        XCTAssertEqual(engine.toggleMode(), .none)
        XCTAssertEqual(engine.code, "z")
        XCTAssertEqual(engine.literalComposition(), .insert("z"))
        XCTAssertEqual(engine.code, "")
    }

    func testBackspaceAndMaximumLength() {
        var engine = CompositionEngine(table: table)
        _ = engine.type("a"); _ = engine.type("b")
        XCTAssertEqual(engine.type("c"), .none)
        XCTAssertEqual(engine.code, "ab")
        XCTAssertEqual(engine.backspace(), .none)
        XCTAssertEqual(engine.code, "a")
        XCTAssertEqual(engine.backspace(), .none)
        XCTAssertEqual(engine.backspace(), .deleteBackward)
    }

    func testEnglishWorksWithoutTableAndPunctuationCommitsCandidate() {
        var empty = CompositionEngine()
        XCTAssertEqual(empty.type("a"), .none)
        _ = empty.toggleMode()
        XCTAssertEqual(empty.type("A"), .insert("A"))
        XCTAssertEqual(empty.space(), .insert(" "))
        var engine = CompositionEngine(table: table)
        _ = engine.type("a")
        XCTAssertEqual(engine.insertLiteral("。"), .insert("甲。"))
        _ = engine.type(","); _ = engine.type(",")
        XCTAssertEqual(engine.space(), .insert("，"))
    }

    func testBundledFcitxDictionaryIncludesCompleteAlphabetAndKnownWords() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "boshiamy", withExtension: "json"))
        let fixture = try JSONDecoder().decode(CanonicalTable.self, from: Data(contentsOf: url))
        let table = CodeTable(name: fixture.name, entries: fixture.entries)
        try table.validate()
        XCTAssertEqual(table.entries.count, 30_916)
        XCTAssertEqual(table.characterCount, 39_694)
        XCTAssertEqual(table.candidates(for: "a").first, "對")
        XCTAssertEqual(table.candidates(for: "hx").first, "愛")
        XCTAssertFalse(table.candidates(for: "[").isEmpty)
        XCTAssertFalse(table.candidates(for: "'").isEmpty)
        XCTAssertEqual(table.maximumCodeLength, 5)
    }

    func testLargeTableTypingDoesNotScanWholeDictionary() throws {
        var entries: [String: [String]] = [:]
        for index in 0..<50_000 {
            var value = index
            var code = ""
            for _ in 0..<4 { code += String(UnicodeScalar(97 + value % 26)!); value /= 26 }
            entries[code] = ["測試"]
        }
        let large = CodeTable(name: "generated", entries: entries)
        try large.validate()
        var engine = CompositionEngine(table: large)
        measure {
            for _ in 0..<1000 {
                _ = engine.type("a"); _ = engine.type("b"); _ = engine.type("c"); _ = engine.type("d")
                _ = engine.space(); engine.reset()
            }
        }
    }

    func testTableMetadataIsDerivedFromEntries() throws {
        XCTAssertEqual(table.characterCount, 4)
        XCTAssertEqual(table.maximumCodeLength, 2)
        XCTAssertEqual(CodeTable(name: "empty", entries: [:]).maximumCodeLength, 4)
    }

    func testValidationUsesCharacterLimitAndRejectsNewlines() throws {
        for word in [String(repeating: "a", count: 128), String(repeating: "👨‍👩‍👧‍👦", count: 128),
                     "a" + String(repeating: "\u{0301}", count: 512)] {
            XCTAssertNoThrow(try CodeTable(name: "boundaries", entries: ["a": [word]]).validate())
        }
        for word in [String(repeating: "a", count: 129), String(repeating: "👨‍👩‍👧‍👦", count: 129), "甲\n乙", "甲\r\n乙", ""] {
            XCTAssertThrowsError(try CodeTable(name: "boundaries", entries: ["a": [word]]).validate())
        }
        var engine = CompositionEngine(table: CodeTable(name: "uppercase", entries: ["hx": ["愛"]]))
        _ = engine.type("H"); _ = engine.type("X")
        XCTAssertEqual(engine.code, "hx")
        XCTAssertEqual(engine.space(), .insert("愛"))
    }

    func testPackedBundleExactlyMatchesCanonicalJSONAndRejectsDamagedData() throws {
        let bundle = Bundle(for: Self.self)
        let data = try Data(contentsOf: XCTUnwrap(bundle.url(forResource: "boshiamy", withExtension: "bin")))
        let json = try Data(contentsOf: XCTUnwrap(bundle.url(forResource: "boshiamy", withExtension: "json")))
        let fixture = try JSONDecoder().decode(CanonicalTable.self, from: json)
        XCTAssertEqual(fixture.version, 1)
        let canonical = CodeTable(name: fixture.name, entries: fixture.entries)
        XCTAssertEqual(try PackedCodeTable.decode(data), canonical)
        XCTAssertEqual(try TableStore.bundled(in: bundle), canonical)
        for end in [0, 1, 4, 5, 8, 12, 13, 14, data.count - 1] {
            XCTAssertThrowsError(try PackedCodeTable.decode(data.prefix(end)))
        }
        var invalid = data
        invalid[4] = 50 // Unsupported format version.
        XCTAssertThrowsError(try PackedCodeTable.decode(invalid))
        invalid = data
        invalid.replaceSubrange(5..<9, with: [255, 255, 255, 255])
        XCTAssertThrowsError(try PackedCodeTable.decode(invalid))
        invalid = data
        invalid.replaceSubrange(9..<13, with: [255, 255, 255, 255])
        XCTAssertThrowsError(try PackedCodeTable.decode(invalid))
        invalid = data
        invalid[13] = 255 // Invalid UTF-8 metadata.
        XCTAssertThrowsError(try PackedCodeTable.decode(invalid))
        invalid = data
        invalid.append(0)
        XCTAssertThrowsError(try PackedCodeTable.decode(invalid))
    }

}
