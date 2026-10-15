import XCTest
import UIKit

final class PerformanceTests: XCTestCase {
    @MainActor
    func testKeyPreviewTracksCaptionStaysInsideKeyboardAndDoesNotInterceptTouches() throws {
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "preview", entries: ["a": ["甲"]]))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(keyboard)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        keyboard.layoutIfNeeded(); CATransaction.flush()
        func preview() -> UIView? { keyboard.subviews.first { $0.accessibilityIdentifier == "key-preview" } }
        func inspect(_ id: String, title: String) throws {
            let key = try XCTUnwrap(button(id, in: keyboard))
            let originalFrame = key.frame
            key.isHighlighted = true
            CATransaction.flush()
            let bubble = try XCTUnwrap(preview())
            let caption = try XCTUnwrap(bubble.subviews.compactMap { $0 as? UILabel }.first)
            XCTAssertFalse(bubble.isHidden)
            XCTAssertEqual(caption.text, title)
            XCTAssertEqual(caption.font.pointSize, 32)
            XCTAssertGreaterThan(bubble.frame.width, key.bounds.width)
            XCTAssertTrue(keyboard.bounds.contains(bubble.frame))
            XCTAssertLessThan(bubble.frame.minY, key.convert(key.bounds, to: keyboard).minY)
            XCTAssertEqual(key.frame, originalFrame)
            XCTAssertFalse(bubble.isUserInteractionEnabled)
            XCTAssertTrue(keyboard.hitTest(key.convert(CGPoint(x: key.bounds.midX, y: key.bounds.midY), to: keyboard), with: nil) === key)
            func checkAnimations(_ layer: CALayer) {
                XCTAssertTrue(layer.animationKeys()?.isEmpty ?? true)
                (layer.sublayers ?? []).forEach(checkAnimations)
            }
            checkAnimations(bubble.layer)
            if id == "key-q" && title == "Q" {
                let image = UIGraphicsImageRenderer(bounds: keyboard.bounds).image { keyboard.layer.render(in: $0.cgContext) }
                let attachment = XCTAttachment(image: image)
                attachment.name = "Pressed Q character preview"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            key.isHighlighted = false
            CATransaction.flush()
            XCTAssertTrue(bubble.isHidden)
            checkAnimations(bubble.layer)
        }
        try inspect("key-q", title: "Q")
        try inspect("key-p", title: "P")
        try inspect("key-1", title: "1")
        try inspect("key-0", title: "0")
        for id in ["shift", "delete", "space", "symbols", "return", "globe"] {
            let key = try XCTUnwrap(button(id, in: keyboard))
            key.isHighlighted = true
            XCTAssertTrue(preview()?.isHidden ?? true, id)
            key.isHighlighted = false
        }
        try XCTUnwrap(button("globe", in: keyboard)).sendActions(for: .touchUpInside)
        try inspect("key-a", title: "A")
        var output = ""
        keyboard.onOutput = { if case .insert(let text) = $0 { output += text } }
        try XCTUnwrap(button("key-a", in: keyboard)).sendActions(for: .touchUpInside)
        XCTAssertEqual(output, "A")
        try inspect("key-a", title: "a")
        keyboard.pressShift(at: 1); keyboard.pressShift(at: 1.2)
        try inspect("key-a", title: "A")
        try XCTUnwrap(button("symbols", in: keyboard)).sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        try inspect("key-/", title: "/")
        try XCTUnwrap(button("more-symbols", in: keyboard)).sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        try inspect("key-€", title: "€")
        let held = try XCTUnwrap(button("key-€", in: keyboard))
        held.isHighlighted = true
        keyboard.clearComposition()
        XCTAssertTrue(preview()?.isHidden == true)
        held.isHighlighted = false
        held.isHighlighted = true
        try XCTUnwrap(button("symbols", in: keyboard)).sendActions(for: .touchUpInside)
        XCTAssertTrue(preview()?.isHidden == true)
        held.isHighlighted = false
        for width: CGFloat in [320, 440, 852, 1024] {
            keyboard.frame.size = CGSize(width: width, height: KeyboardView.preferredHeight(width: width, compact: false))
            keyboard.layoutIfNeeded()
            try inspect("key-q", title: "Q")
            try inspect("key-p", title: "P")
            try inspect("key-0", title: "0")
        }
        let q = try XCTUnwrap(button("key-q", in: keyboard))
        q.isHighlighted = true
        keyboard.frame.size.width = 393
        keyboard.layoutIfNeeded()
        XCTAssertTrue(preview()?.isHidden == true)
        q.isHighlighted = false
        q.isHighlighted = true
        keyboard.removeFromSuperview()
        XCTAssertTrue(preview()?.isHidden == true)
    }

    @MainActor
    func testGlobeOnlyLayoutKeepsNativeSwitchSeparateFromPreviewLanguage() throws {
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "native switch", entries: ["a": ["甲"]]))
        keyboard.layoutIfNeeded()
        XCTAssertNil(button("mode", in: keyboard))
        let globe = try XCTUnwrap(button("globe", in: keyboard))
        let space = try XCTUnwrap(button("space", in: keyboard))
        XCTAssertEqual(space.frame.width, NativeKeyboardGeometry(width: 393, compact: false).frames(for: .bottom, count: 4)[2].width, accuracy: 0.5)
        XCTAssertLessThan(globe.convert(globe.bounds, to: keyboard).maxX,
                          space.convert(space.bounds, to: keyboard).minX)
        var output: [CompositionEngine.Output] = []
        keyboard.onOutput = { output.append($0) }
        keyboard.onGlobe = { [weak keyboard] _, _ in keyboard?.clearComposition() }
        try XCTUnwrap(button("key-a", in: keyboard)).sendActions(for: .touchUpInside)
        output.removeAll()
        globe.sendActions(for: .touchUpInside)
        XCTAssertEqual(keyboard.engine.mode, .chinese)
        XCTAssertEqual(keyboard.engine.code, "a") // sendActions does not synthesize a native touch event.
        XCTAssertTrue(output.isEmpty)
        keyboard.clearComposition()
        keyboard.onGlobe = nil
        globe.sendActions(for: .touchUpInside)
        XCTAssertEqual(keyboard.engine.mode, .english)
        XCTAssertEqual(globe.accessibilityValue, "英文")
    }

    private func report(_ name: String, iterations: Int = 21, operation: () throws -> Void) rethrows {
        try operation() // Warm code and framework caches before collecting samples.
        var samples: [Double] = []
        for _ in 0..<iterations {
            let start = CACurrentMediaTime()
            try operation()
            samples.append((CACurrentMediaTime() - start) * 1000)
        }
        samples.sort()
        print("PERFORMANCE \(name) median_ms=\(samples[samples.count / 2]) p95_ms=\(samples[Int(ceil(Double(samples.count) * 0.95)) - 1])")
    }

    @MainActor
    func testCandidateRenderingPerformance() throws {
        for count in [7, 1000] {
            let keyboard = makeKeyboard()
            keyboard.load(table: CodeTable(name: "performance", entries: ["a": (0..<count).map { "候選\($0)" }]))
            keyboard.layoutIfNeeded()
            let type = try XCTUnwrap(button("key-a", in: keyboard))
            let delete = try XCTUnwrap(button("delete", in: keyboard))
            report("candidate_\(count)_type_delete") {
                type.sendActions(for: .touchUpInside)
                keyboard.layoutIfNeeded()
                delete.sendActions(for: .touchUpInside)
                keyboard.layoutIfNeeded()
            }
        }
    }

    func testRepeatedTableLoadPerformance() throws {
        let bundle = Bundle(for: Self.self)
        let table = try XCTUnwrap(TableStore.bundled(in: bundle))
        try report("bundled_table_load") {
            XCTAssertEqual(try TableStore.bundled(in: bundle)?.entries.count, 30_916)
        }
        report("table_metadata_100_reads") {
            for _ in 0..<100 {
                XCTAssertEqual(table.characterCount, 39_694)
                XCTAssertEqual(table.maximumCodeLength, 5)
            }
        }
    }

    @MainActor
    func testKeyboardControlsPerformance() throws {
        report("keyboard_create_layout") {
            autoreleasepool {
                let keyboard = makeKeyboard()
                keyboard.layoutIfNeeded()
            }
        }
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "controls", entries: ["a": ["甲", "乙"]]))
        keyboard.layoutIfNeeded()
        for id in ["shift", "globe", "symbols"] {
            try report("\(id)_toggle_pair") {
                for _ in 0..<2 {
                    try XCTUnwrap(self.button(id, in: keyboard)).sendActions(for: .touchUpInside)
                    keyboard.layoutIfNeeded()
                }
            }
        }
        try XCTUnwrap(button("symbols", in: keyboard)).sendActions(for: .touchUpInside)
        try report("symbol_page_toggle_pair") {
            for _ in 0..<2 {
                try XCTUnwrap(self.button("more-symbols", in: keyboard)).sendActions(for: .touchUpInside)
                keyboard.layoutIfNeeded()
            }
        }
        try XCTUnwrap(button("symbols", in: keyboard)).sendActions(for: .touchUpInside)
        try XCTUnwrap(button("globe", in: keyboard)).sendActions(for: .touchUpInside)
        let type = try XCTUnwrap(button("key-a", in: keyboard))
        let delete = try XCTUnwrap(button("delete", in: keyboard))
        report("english_type_delete_100") {
            for _ in 0..<100 {
                type.sendActions(for: .touchUpInside)
                keyboard.layoutIfNeeded()
                delete.sendActions(for: .touchUpInside)
                keyboard.layoutIfNeeded()
            }
        }
    }

    @MainActor
    func testCandidateCellsStayBoundedAndSelectCorrectWordAfterReuse() throws {
        let words = (0..<1000).map { "候選\($0)" }
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "reuse", entries: ["a": words, "ab": ["第二字碼的候選"]]))
        var output: CompositionEngine.Output = .none
        keyboard.onOutput = { output = $0 }
        keyboard.layoutIfNeeded()
        let type = try XCTUnwrap(button("key-a", in: keyboard))
        type.sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        let collection = try XCTUnwrap(descendant(UICollectionView.self, in: keyboard))
        XCTAssertEqual(collection.numberOfItems(inSection: 0), 1000)
        XCTAssertNotNil(button("candidate-0", in: keyboard), "collection=\(collection.frame), hidden=\(collection.isHidden), parent=\(String(describing: collection.superview?.frame)), visible=\(collection.visibleCells.count), content=\(collection.contentSize)")
        XCTAssertLessThan(collection.visibleCells.count, 20)
        collection.scrollToItem(at: IndexPath(item: 999, section: 0), at: .right, animated: false)
        keyboard.layoutIfNeeded()
        try XCTUnwrap(button("candidate-999", in: keyboard)).sendActions(for: .touchUpInside)
        XCTAssertEqual(output, .insert("候選999"))
        type.sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        XCTAssertEqual(collection.contentOffset.x, 0, accuracy: 1)
        try XCTUnwrap(button("key-b", in: keyboard)).sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        try XCTUnwrap(button("candidate-0", in: keyboard)).sendActions(for: .touchUpInside)
        XCTAssertEqual(output, .insert("第二字碼的候選"))
    }

    @MainActor
    func testSameCountCandidateReplacementUpdatesWidthsTextAndSelection() throws {
        let old = (0..<1000).map { "舊\($0)" }
        let new = (0..<1000).map { "新候選文字\($0)" }
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "same count", entries: ["a": old, "ab": new]))
        var output: CompositionEngine.Output = .none
        keyboard.onOutput = { output = $0 }
        keyboard.layoutIfNeeded()
        try XCTUnwrap(button("key-a", in: keyboard)).sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        let collection = try XCTUnwrap(descendant(UICollectionView.self, in: keyboard))
        collection.scrollToItem(at: IndexPath(item: 999, section: 0), at: .right, animated: false)
        keyboard.layoutIfNeeded()
        try XCTUnwrap(button("key-b", in: keyboard)).sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        XCTAssertEqual(collection.contentOffset.x, 0, accuracy: 0.5)
        let firstCell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 0, section: 0)))
        let first = try XCTUnwrap(button("candidate-0", in: firstCell))
        XCTAssertEqual(textLabel("candidate-text", in: first)?.text, new[0])
        let shaped = (new[0] as NSString).size(withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)]).width
        XCTAssertGreaterThanOrEqual(first.bounds.width, ceil(shaped) + 28)
        collection.scrollToItem(at: IndexPath(item: 999, section: 0), at: .right, animated: false)
        keyboard.layoutIfNeeded()
        let lastCell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 999, section: 0)))
        try XCTUnwrap(button("candidate-999", in: lastCell)).sendActions(for: .touchUpInside)
        XCTAssertEqual(output, .insert(new[999]))
        XCTAssertEqual(keyboard.engine.code, "")
    }

    @MainActor
    func testChangingCandidateListsPerformance() throws {
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "changing", entries: [
            "a": (0..<1000).map { "候選\($0)" }, "ab": (0..<1000).map { "另一候選\($0)" }
        ]))
        keyboard.layoutIfNeeded()
        let a = try XCTUnwrap(button("key-a", in: keyboard))
        let b = try XCTUnwrap(button("key-b", in: keyboard))
        let delete = try XCTUnwrap(button("delete", in: keyboard))
        report("candidate_changed_lists_1000") {
            for key in [a, b, delete, delete] {
                key.sendActions(for: .touchUpInside)
                keyboard.layoutIfNeeded()
            }
        }
        XCTAssertEqual(keyboard.engine.code, "")
        let real = try XCTUnwrap(TableStore.bundled(in: Bundle(for: Self.self)))
        keyboard.load(table: real)
        let h = try XCTUnwrap(button("key-h", in: keyboard))
        let x = try XCTUnwrap(button("key-x", in: keyboard))
        let space = try XCTUnwrap(button("space", in: keyboard))
        var text = ""
        keyboard.onOutput = { if case .insert(let value) = $0 { text += value } }
        report("real_dictionary_hx_a_typing") {
            text = ""
            for key in [h, x, space, a, space] {
                key.sendActions(for: .touchUpInside)
                keyboard.layoutIfNeeded()
            }
            XCTAssertEqual(text, "愛對")
        }
    }

    @MainActor
    func testUncachedDictionaryKeyboardStartupPerformance() throws {
        let bundle = Bundle(for: Self.self)
        let packed = try XCTUnwrap(bundle.url(forResource: "boshiamy", withExtension: "bin"))
        try report("startup_packed_dictionary_keyboard") {
            try autoreleasepool {
                let table = try PackedCodeTable.decode(Data(contentsOf: packed))
                let keyboard = makeKeyboard()
                keyboard.load(table: table)
                keyboard.layoutIfNeeded()
                XCTAssertEqual(keyboard.engine.maximumCodeLength, 5)
            }
        }
    }

    func testPackedDictionaryDecoderPerformance() throws {
        let table = try XCTUnwrap(TableStore.bundled(in: Bundle(for: Self.self)))
        let data = packedData(table)
        XCTAssertEqual(try PackedCodeTable.decode(data), table)
        try report("decode_packed_bundle") {
            let decoded = try PackedCodeTable.decode(data)
            XCTAssertEqual(decoded.characterCount, 39_694)
            XCTAssertEqual(decoded.candidates(for: "hx").first, "愛")
        }
    }

    private func packedData(_ table: CodeTable) -> Data {
        var data = Data(PackedCodeTable.magic)
        func integer(_ value: Int, bytes: Int) {
            for shift in 0..<bytes { data.append(UInt8((value >> (shift * 8)) & 255)) }
        }
        integer(table.entries.count, bytes: 4)
        integer(table.name.utf8.count, bytes: 4)
        data.append(contentsOf: table.name.utf8)
        for code in table.entries.keys.sorted() {
            let words = table.entries[code]!
            integer(code.utf8.count, bytes: 1)
            data.append(contentsOf: code.utf8)
            integer(words.count, bytes: 2)
            for word in words {
                integer(word.utf8.count, bytes: 4)
                data.append(contentsOf: word.utf8)
            }
        }
        return data
    }

    @MainActor
    func testControlActionsRemainCorrectAcrossPageReuse() throws {
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "controls", entries: ["a": ["甲"]]))
        var text = ""
        keyboard.onOutput = { if case .insert(let value) = $0 { text += value } }
        func tap(_ id: String) throws {
            try XCTUnwrap(button(id, in: keyboard)).sendActions(for: .touchUpInside)
            keyboard.layoutIfNeeded()
        }
        XCTAssertEqual(try XCTUnwrap(button("globe", in: keyboard)).accessibilityValue, "中文")
        try tap("globe")
        XCTAssertEqual(keyboard.engine.mode, .english)
        XCTAssertEqual(try XCTUnwrap(button("globe", in: keyboard)).accessibilityValue, "英文")
        try tap("key-a")
        XCTAssertEqual(text, "A")
        try tap("symbols")
        XCTAssertEqual(try XCTUnwrap(button("globe", in: keyboard)).accessibilityValue, "英文")
        try tap("key-/")
        try tap("more-symbols")
        try tap("key-]")
        XCTAssertEqual(text, "A/]")
        try tap("globe")
        XCTAssertEqual(try XCTUnwrap(button("globe", in: keyboard)).accessibilityValue, "中文")
        try tap("key-]")
        XCTAssertEqual(keyboard.engine.code, "]")
        try tap("globe") // Invalid composition must still block mode changes.
        XCTAssertEqual(keyboard.engine.mode, .chinese)
        XCTAssertEqual(try XCTUnwrap(button("globe", in: keyboard)).accessibilityValue, "中文")
        try tap("delete")
        try tap("globe")
        XCTAssertEqual(try XCTUnwrap(button("globe", in: keyboard)).accessibilityValue, "英文")
        try tap("symbols")
        try tap("key-a")
        try tap("shift")
        try tap("key-a")
        XCTAssertEqual(text, "A/]AA")
    }

    @MainActor
    func testThreeShiftStatesConsumeOnlyOneEnglishLetterAndKeepCapsLock() throws {
        let keyboard = makeKeyboard()
        var text = ""
        keyboard.onOutput = { if case .insert(let value) = $0 { text += value } }
        func tap(_ id: String) throws {
            try XCTUnwrap(button(id, in: keyboard)).sendActions(for: .touchUpInside)
            keyboard.layoutIfNeeded()
        }
        try tap("globe")
        let shift = try XCTUnwrap(button("shift", in: keyboard))
        XCTAssertEqual(keyboard.shiftState, .once)
        XCTAssertEqual(shift.accessibilityValue, "下一個字母大寫")
        XCTAssertEqual(shift.image(for: .normal), UIImage(systemName: "shift.fill"))
        try tap("key-1")
        try tap("symbols"); try tap("key-/"); try tap("symbols")
        XCTAssertEqual(keyboard.shiftState, .once)
        try tap("key-a"); try tap("key-b")
        XCTAssertEqual(text, "1/Ab")
        XCTAssertEqual(keyboard.shiftState, .off)
        XCTAssertEqual(shift.image(for: .normal), UIImage(systemName: "shift"))
        keyboard.pressShift(at: 10)
        keyboard.pressShift(at: 10.2)
        XCTAssertEqual(keyboard.shiftState, .locked)
        XCTAssertEqual(shift.image(for: .normal), UIImage(systemName: "capslock.fill"))
        try tap("key-c"); try tap("space"); try tap("key-d")
        try tap("symbols"); try tap("more-symbols"); try tap("symbols")
        XCTAssertEqual(keyboard.shiftState, .locked)
        try tap("key-e")
        XCTAssertEqual(text, "1/AbC DE")
        keyboard.pressShift(at: 11)
        XCTAssertEqual(keyboard.shiftState, .off)
        try tap("key-f")
        XCTAssertEqual(text, "1/AbC DEf")
    }

    @MainActor
    func testSlowShiftTapsAndInterveningKeysDoNotLockCaps() throws {
        let keyboard = makeKeyboard()
        keyboard.pressShift(at: 1)
        XCTAssertEqual(keyboard.shiftState, .once)
        keyboard.pressShift(at: 2)
        XCTAssertEqual(keyboard.shiftState, .off)
        keyboard.pressShift(at: 3)
        try XCTUnwrap(button("key-1", in: keyboard)).sendActions(for: .touchUpInside)
        keyboard.pressShift(at: 3.1)
        XCTAssertEqual(keyboard.shiftState, .off)
        keyboard.pressShift(at: 4)
        keyboard.pressShift(at: 4.1)
        XCTAssertEqual(keyboard.shiftState, .locked)
        try XCTUnwrap(button("globe", in: keyboard)).sendActions(for: .touchUpInside)
        XCTAssertEqual(keyboard.shiftState, .once)
        try XCTUnwrap(button("globe", in: keyboard)).sendActions(for: .touchUpInside)
        XCTAssertEqual(keyboard.shiftState, .off)
    }

    @MainActor
    func testReferenceLayoutPreservesCaseHeightAndSpacebarTouches() throws {
        let keyboard = KeyboardView(frame: CGRect(x: 0, y: 0, width: 393, height: KeyboardView.preferredHeight(width: 393, compact: false)))
        keyboard.needsGlobe = false
        keyboard.load(table: CodeTable(name: "layout", entries: ["a": ["甲"]]))
        keyboard.layoutIfNeeded()
        let a = try XCTUnwrap(button("key-a", in: keyboard))
        let idleKeyHeight = a.bounds.height
        XCTAssertEqual(a.title(for: .normal), "A")
        XCTAssertEqual(a.titleLabel?.font.pointSize, 22)
        XCTAssertFalse(a.titleLabel?.font.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        XCTAssertFalse(keyboard.isShowingComposition)
        a.sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        XCTAssertTrue(keyboard.isShowingComposition)
        XCTAssertEqual(a.bounds.height, idleKeyHeight, accuracy: 0.5)
        try XCTUnwrap(button("space", in: keyboard)).sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        XCTAssertEqual(keyboard.bounds.height, KeyboardView.preferredHeight(width: 393, compact: false))
        XCTAssertEqual(a.bounds.height, idleKeyHeight, accuracy: 0.5)
        try XCTUnwrap(button("globe", in: keyboard)).sendActions(for: .touchUpInside)
        XCTAssertEqual(a.title(for: .normal), "A")
        a.sendActions(for: .touchUpInside)
        XCTAssertEqual(a.title(for: .normal), "a")
        try XCTUnwrap(button("shift", in: keyboard)).sendActions(for: .touchUpInside)
        XCTAssertEqual(a.title(for: .normal), "A")
        let globe = try XCTUnwrap(button("globe", in: keyboard))
        _ = try XCTUnwrap(button("space", in: keyboard))
        XCTAssertFalse(globe.isHidden)
        XCTAssertFalse(globe.isUserInteractionEnabled)
        let point = globe.convert(CGPoint(x: globe.bounds.midX, y: globe.bounds.midY), to: keyboard)
        XCTAssertFalse(keyboard.hitTest(point, with: nil) === globe)
        keyboard.needsGlobe = true
        XCTAssertTrue(keyboard.hitTest(point, with: nil) === globe)
    }

    private struct NativeFixture: Decodable {
        struct Rectangle: Decodable { let x, y, width, height: CGFloat
            var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
        }
        struct Key: Decodable { let label: String; let cap: Rectangle; let ink: Rectangle? }
        struct Capture: Decodable { let name: String; let screenWidth: CGFloat; let keys: [Key] }
        let captures: [Capture]
    }

    private func nativeFixture() throws -> NativeFixture {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "NativeEnglishKeyFrames", withExtension: "json"))
        return try JSONDecoder().decode(NativeFixture.self, from: Data(contentsOf: url))
    }

    @MainActor
    func testEveryKeyMatchesMeasuredNativeEnglishDimensions() throws {
        for capture in try nativeFixture().captures {
            let compact = capture.name.hasPrefix("landscape")
            let keyboard = KeyboardView(frame: CGRect(x: 0, y: 0, width: capture.screenWidth,
                height: KeyboardView.preferredHeight(width: capture.screenWidth, compact: compact)))
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: capture.screenWidth, height: 874))
            let root = UIViewController()
            root.traitOverrides.verticalSizeClass = compact ? .compact : .regular
            window.rootViewController = root
            root.view.addSubview(keyboard)
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            keyboard.layoutIfNeeded()
            let q = try XCTUnwrap(button("key-q", in: keyboard))
            let qFrame = q.convert(q.bounds, to: keyboard)
            let nativeQ = try XCTUnwrap(capture.keys.first { $0.label.lowercased() == "q" }).cap
            for key in capture.keys {
                let id: String
                switch key.label {
                case "shift", "delete", "return": id = key.label
                case "numbers": id = "symbols"
                case "Emoji": id = "globe"
                case " ": id = "space"
                default: id = "key-" + key.label.lowercased()
                }
                let control = try XCTUnwrap(button(id, in: keyboard))
                let frame = control.convert(control.bounds, to: keyboard)
                let tolerance: CGFloat = 1.0 / 3 + 0.01
                XCTAssertEqual(frame.minX, key.cap.x, accuracy: tolerance, "\(capture.name): \(id) x")
                XCTAssertEqual(frame.minY - qFrame.minY, key.cap.y - nativeQ.y, accuracy: tolerance, "\(capture.name): \(id) y")
                XCTAssertEqual(frame.width, key.cap.width, accuracy: tolerance, "\(capture.name): \(id) width")
                XCTAssertEqual(frame.height, key.cap.height, accuracy: tolerance, "\(capture.name): \(id) height")
            }
            let geometry = NativeKeyboardGeometry(width: capture.screenWidth, compact: compact)
            for (i, letter) in Array("qwertyuiop").enumerated() {
                let letterKey = try XCTUnwrap(button("key-\(letter)", in: keyboard))
                let digit = try XCTUnwrap(button("key-\(Array("1234567890")[i])", in: keyboard))
                XCTAssertEqual(digit.frame.minX, letterKey.frame.minX)
                XCTAssertEqual(digit.frame.width, letterKey.frame.width)
                XCTAssertEqual(qFrame.minY - digit.convert(digit.bounds, to: keyboard).minY,
                               geometry.origin(of: .letters) - geometry.origin(of: .numbers), accuracy: 0.34)
            }
        }
    }

    @MainActor
    func testNativeGlyphBoundsMatchReference() throws {
        var observed: [[String: Any]] = []
        var differences: [String] = []
        for capture in try nativeFixture().captures {
            let compact = capture.name.hasPrefix("landscape")
            let keyboard = KeyboardView(frame: CGRect(x: 0, y: 0, width: capture.screenWidth,
                height: KeyboardView.preferredHeight(width: capture.screenWidth, compact: compact)))
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: capture.screenWidth, height: 874))
            let root = UIViewController()
            root.traitOverrides.verticalSizeClass = compact ? .compact : .regular
            window.rootViewController = root
            root.view.addSubview(keyboard)
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            keyboard.overrideUserInterfaceStyle = .light
            keyboard.layoutIfNeeded()
            if capture.name.hasSuffix("lowercase") {
                try XCTUnwrap(button("globe", in: keyboard)).sendActions(for: .touchUpInside)
                keyboard.pressShift(at: 1)
                keyboard.layoutIfNeeded()
            }
            for key in capture.keys where key.label.count == 1 && key.label != " " {
                let control = try XCTUnwrap(button("key-" + key.label.lowercased(), in: keyboard))
                let expected = try XCTUnwrap(key.ink).rect
                let format = UIGraphicsImageRendererFormat(); format.scale = 3; format.preferredRange = .standard
                let image = UIGraphicsImageRenderer(bounds: control.bounds, format: format).image { context in
                    UIColor.white.setFill(); context.fill(control.bounds)
                    control.layer.render(in: context.cgContext)
                }
                let cg = try XCTUnwrap(image.cgImage)
                var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
                let bitmap = try XCTUnwrap(CGContext(data: &bytes, width: cg.width, height: cg.height, bitsPerComponent: 8,
                    bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                bitmap.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
                var minX = cg.width, minY = cg.height, maxX = -1, maxY = -1
                for y in 0..<cg.height {
                    for x in 0..<cg.width {
                        let i = (y * cg.width + x) * 4
                        if max(bytes[i], bytes[i + 1], bytes[i + 2]) < 100 && bytes[i + 3] > 127 {
                            minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
                        }
                    }
                }
                XCTAssertGreaterThanOrEqual(maxX, minX)
                let actual = CGRect(x: CGFloat(minX) / 3, y: CGFloat(minY) / 3,
                                    width: CGFloat(maxX - minX + 1) / 3, height: CGFloat(maxY - minY + 1) / 3)
                observed.append(["name": capture.name, "width": capture.screenWidth, "label": key.label,
                    "actual": [actual.minX, actual.minY, actual.width, actual.height],
                    "expected": [expected.minX, expected.minY, expected.width, expected.height]])
                for (name, value, target) in [("centerX", actual.midX, expected.midX), ("centerY", actual.midY, expected.midY),
                                               ("width", actual.width, expected.width), ("height", actual.height, expected.height)] {
                    if abs(value - target) > 0.34 { differences.append("\(capture.screenWidth) \(capture.name) \(key.label) \(name): \(value) vs \(target)") }
                }
            }
        }
        let data = try JSONSerialization.data(withJSONObject: observed, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "Native glyph comparison"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(differences.isEmpty, differences.prefix(20).joined(separator: "\n"))
    }

    @MainActor
    func testTypingDoesNotResizeKeyboardBetweenLettersAndWords() throws {
        let keyboard = makeKeyboard()
        keyboard.load(table: try XCTUnwrap(TableStore.bundled(in: Bundle(for: Self.self))))
        keyboard.layoutIfNeeded()
        let idleHeight = keyboard.bounds.height
        var text = ""
        keyboard.onOutput = { if case .insert(let value) = $0 { text += value } }
        for id in ["key-h", "key-x", "space", "key-a", "space"] {
            try XCTUnwrap(button(id, in: keyboard)).sendActions(for: .touchUpInside)
            keyboard.layoutIfNeeded()
            XCTAssertEqual(keyboard.bounds.height, idleHeight, "Typing must not resize the host keyboard at \(id)")
        }
        XCTAssertEqual(text, "愛對")
    }

    @MainActor
    func testFastTypingNearKeyEdgesDoesNotFallIntoDeadGutters() throws {
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "touches", entries: ["a": ["甲"]]))
        keyboard.layoutIfNeeded()
        let q = try XCTUnwrap(button("key-q", in: keyboard))
        let w = try XCTUnwrap(button("key-w", in: keyboard))
        let a = try XCTUnwrap(button("key-a", in: keyboard))
        let qFrame = q.convert(q.bounds, to: keyboard)
        let wFrame = w.convert(w.bounds, to: keyboard)
        let aFrame = a.convert(a.bounds, to: keyboard)
        let horizontal = CGPoint(x: qFrame.maxX + (wFrame.minX - qFrame.maxX) / 4, y: qFrame.midY)
        let vertical = CGPoint(x: qFrame.midX, y: qFrame.maxY + (aFrame.minY - qFrame.maxY) / 4)
        for point in [horizontal, vertical] {
            XCTAssertTrue(keyboard.hitTest(point, with: nil) === q,
                          "A fast tap next to Q must reach Q instead of an inert row/background: \(point)")
            XCTAssertTrue(q.point(inside: q.convert(point, from: keyboard), with: nil))
        }
    }

    @MainActor
    func testExactCandidateFramesFitShapedUnicodeText() throws {
        var words = ["候選0", "候選123", "測試", "ASCII", "ffi", "e\u{301}", "👩‍💻", "𠮷", "，。", "Ａ", "العربية", "測試🙂", "A候B", "測試ABC測試", String(repeating: "測試", count: 64)]
        let table = try XCTUnwrap(TableStore.bundled(in: Bundle(for: Self.self)))
        words += Set(table.entries.values.flatMap { $0 }).sorted()
        let keyboard = makeKeyboard()
        let font = UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)
        for start in stride(from: 0, to: words.count, by: 1000) {
            let batch = Array(words[start..<min(start + 1000, words.count)])
            keyboard.load(table: CodeTable(name: "widths", entries: ["a": batch]))
            keyboard.layoutIfNeeded()
            try XCTUnwrap(button("key-a", in: keyboard)).sendActions(for: .touchUpInside)
            keyboard.layoutIfNeeded()
            let collection = try XCTUnwrap(descendant(UICollectionView.self, in: keyboard))
            var previousEnd: CGFloat = -4
            for (index, word) in batch.enumerated() {
                let attributes = try XCTUnwrap(collection.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0)))
                let expected = max(44, ceil((word as NSString).size(withAttributes: [.font: font]).width) + 28)
                XCTAssertEqual(attributes.frame.width, expected, accuracy: 1, word)
                XCTAssertEqual(attributes.frame.minX, previousEnd + 4, accuracy: 0.1)
                previousEnd = attributes.frame.maxX
            }
            XCTAssertEqual(collection.contentSize.width, max(previousEnd, collection.bounds.width), accuracy: 0.1)
        }
    }

    @MainActor
    func testShiftAndCapsLockUpdatesDoNotFade() throws {
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "shift animation", entries: ["a": ["甲"]]))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(keyboard)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        keyboard.layoutIfNeeded(); CATransaction.flush()
        let shift = try XCTUnwrap(button("shift", in: keyboard))
        let a = try XCTUnwrap(button("key-a", in: keyboard))
        var fades: [String] = []
        func inspect(_ name: String, state: KeyboardView.ShiftState, title: String) {
            keyboard.layoutIfNeeded(); CATransaction.flush()
            XCTAssertEqual(keyboard.shiftState, state)
            XCTAssertEqual(a.title(for: .normal), title)
            let visibleCaptions = a.subviews.compactMap { $0 as? UILabel }.filter { !$0.isHidden && $0.text != nil }
            XCTAssertEqual(visibleCaptions.map { $0.text! }, [title])
            XCTAssertEqual(visibleCaptions.first?.font.pointSize, title == title.lowercased() ? 25 : 22)
            XCTAssertFalse(visibleCaptions.first?.font.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
            let expectedFrame = a.bounds.offsetBy(dx: NativeKeyboardTypography.offset(for: title, compact: false).x,
                                                  dy: NativeKeyboardTypography.offset(for: title, compact: false).y)
            XCTAssertEqual(visibleCaptions.first!.frame.minX, expectedFrame.minX, accuracy: 0.001)
            XCTAssertEqual(visibleCaptions.first!.frame.minY, expectedFrame.minY, accuracy: 0.001)
            XCTAssertEqual(visibleCaptions.first!.frame.size, expectedFrame.size)
            func collect(_ layer: CALayer) {
                for key in layer.animationKeys() ?? [] {
                    let duration = layer.animation(forKey: key)?.duration ?? 0
                    if duration > 0 { fades.append("\(name): \(type(of: layer)) \(key) \(duration * 1000)ms") }
                }
                (layer.sublayers ?? []).forEach(collect)
            }
            collect(shift.layer)
            for letter in "qwertyuiopasdfghjklzxcvbnm" {
                if let key = button("key-\(letter)", in: keyboard) { collect(key.layer) }
            }
        }
        try XCTUnwrap(button("globe", in: keyboard)).sendActions(for: .touchUpInside)
        inspect("english once", state: .once, title: "A")
        shift.isHighlighted = true; CATransaction.flush()
        shift.isHighlighted = false; CATransaction.flush()
        inspect("shift feedback", state: .once, title: "A")
        keyboard.pressShift(at: 1)
        inspect("off", state: .off, title: "a")
        keyboard.pressShift(at: 2)
        inspect("once", state: .once, title: "A")
        keyboard.pressShift(at: 2.1)
        inspect("locked", state: .locked, title: "A")
        keyboard.pressShift(at: 3)
        inspect("unlock", state: .off, title: "a")
        keyboard.pressShift(at: 4)
        var output = ""
        keyboard.onOutput = { if case .insert(let text) = $0 { output += text } }
        a.sendActions(for: .touchUpInside)
        inspect("consume once", state: .off, title: "a")
        XCTAssertEqual(output, "A")
        print("SHIFT_FADE count=\(fades.count) examples=\(Array(fades.prefix(8)))")
        XCTAssertTrue(fades.isEmpty, "Shift symbols and letter case must update immediately: \(fades.prefix(5))")
    }

    @MainActor
    func testSymbolPagesUpdateWithoutAnimations() throws {
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "page animation", entries: ["a": ["甲"]]))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(keyboard)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        keyboard.layoutIfNeeded(); CATransaction.flush()
        let page = try XCTUnwrap(button("symbols", in: keyboard))
        var animations: [String] = []
        func inspect(_ stage: String, pageTitle: String, character: String) throws {
            keyboard.layoutIfNeeded(); CATransaction.flush()
            XCTAssertEqual(page.title(for: .normal), pageTitle)
            let pageCaptions = page.subviews.compactMap { $0 as? UILabel }.filter { !$0.isHidden && $0.text != nil }
            XCTAssertEqual(pageCaptions.map { $0.text! }, [pageTitle])
            let key = try XCTUnwrap(button("key-\(character)", in: keyboard))
            XCTAssertFalse(key.isHidden)
            func collect(_ layer: CALayer) {
                for key in layer.animationKeys() ?? [] {
                    let duration = layer.animation(forKey: key)?.duration ?? 0
                    if duration > 0 { animations.append("\(stage): \(type(of: layer)) \(key) \(duration * 1000)ms") }
                }
                (layer.sublayers ?? []).forEach(collect)
            }
            collect(keyboard.layer)
        }
        for mode in ["Chinese", "English"] {
            if mode == "English" { try XCTUnwrap(button("globe", in: keyboard)).sendActions(for: .touchUpInside) }
            page.sendActions(for: .touchUpInside)
            try inspect("\(mode) symbols", pageTitle: "ABC", character: "/")
            try XCTUnwrap(button("more-symbols", in: keyboard)).sendActions(for: .touchUpInside)
            try inspect("\(mode) more symbols", pageTitle: "ABC", character: "€")
            page.sendActions(for: .touchUpInside)
            try inspect("\(mode) alphabet", pageTitle: "123", character: "a")
        }
        print("SYMBOL_PAGE_ANIMATIONS count=\(animations.count) examples=\(Array(animations.prefix(10)))")
        XCTAssertTrue(animations.isEmpty, "Symbol/alphabet page switches must be immediate: \(animations.prefix(10))")
    }

    @MainActor
    func testKeyPressFeedbackDoesNotWaitForAnImplicitAnimation() throws {
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "feedback", entries: ["a": ["甲"]]))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(keyboard)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        keyboard.layoutIfNeeded()
        CATransaction.flush()
        let key = try XCTUnwrap(button("key-a", in: keyboard))
        let surface = try XCTUnwrap(key.layer.sublayers?.compactMap { $0 as? CAGradientLayer }.first)
        key.isHighlighted = true
        CATransaction.flush()
        XCTAssertEqual(surface.opacity, 0.75)
        XCTAssertTrue(surface.animationKeys()?.isEmpty ?? true, "Press feedback must update immediately, not animate toward the pressed color")
        key.isHighlighted = false
        CATransaction.flush()
        XCTAssertTrue(surface.animationKeys()?.isEmpty ?? true)
    }

    @MainActor
    func testVisibleCompositionRenderingPerformance() throws {
        let keyboard = makeKeyboard()
        keyboard.load(table: try XCTUnwrap(TableStore.bundled(in: Bundle(for: Self.self))))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(keyboard)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        keyboard.layoutIfNeeded()
        CATransaction.flush()
        let a = try XCTUnwrap(button("key-a", in: keyboard))
        a.sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        CATransaction.flush()
        let label = try XCTUnwrap(textLabel("composition-text", in: keyboard))
        print("TEXT_RENDER composition_fade_ms=\((label.layer.animation(forKey: "opacity")?.duration ?? 0) * 1000)")
        keyboard.clearComposition()
        let sequence = try ["key-h", "key-x", "space", "key-a", "space"].map { try XCTUnwrap(button($0, in: keyboard)) }
        report("visible_real_dictionary_hx_a_typing") {
            for key in sequence {
                key.sendActions(for: .touchUpInside)
                keyboard.layoutIfNeeded()
                CATransaction.flush()
            }
        }
    }

    @MainActor
    func testCompositionAndCandidateTextUpdatesDoNotAnimate() throws {
        continueAfterFailure = false
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "animation", entries: ["a": ["甲", "乙"], "ab": ["更新", "文字"]]))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(keyboard)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        keyboard.layoutIfNeeded()
        CATransaction.flush()
        func topAnimations() -> [String] {
            let code = button("composition", in: keyboard)!
            let area = code.superview!
            func animations(_ layer: CALayer) -> [String] {
                (layer.animationKeys() ?? []).map { "\(type(of: layer)): \($0)" }
                    + (layer.sublayers ?? []).flatMap { animations($0) }
            }
            return animations(area.layer)
        }
        try XCTUnwrap(button("key-a", in: keyboard)).sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        CATransaction.flush()
        XCTAssertTrue(topAnimations().isEmpty, "First code/candidates must appear immediately: \(topAnimations())")
        try XCTUnwrap(button("key-b", in: keyboard)).sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        CATransaction.flush()
        XCTAssertTrue(topAnimations().isEmpty, "Changed code/candidates must replace immediately: \(topAnimations())")
        let code = try XCTUnwrap(button("composition", in: keyboard))
        XCTAssertEqual(textLabel("composition-text", in: code)?.text, "AB")
        XCTAssertEqual(textLabel("candidate-text", in: try XCTUnwrap(button("candidate-0", in: keyboard)))?.text, "更新")
        let candidate = try XCTUnwrap(button("candidate-0", in: keyboard))
        candidate.isHighlighted = true
        CATransaction.flush()
        candidate.isHighlighted = false
        CATransaction.flush()
        XCTAssertTrue(topAnimations().isEmpty, "Candidate feedback must not fade: \(topAnimations())")
        candidate.sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        CATransaction.flush()
        XCTAssertTrue(topAnimations().isEmpty, "Commit must clear immediately: \(topAnimations())")
        keyboard.load(table: CodeTable(name: "scroll animation", entries: ["a": (0..<1000).map { "候選\($0)" }]))
        try XCTUnwrap(button("key-a", in: keyboard)).sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        let collection = try XCTUnwrap(descendant(UICollectionView.self, in: keyboard))
        collection.scrollToItem(at: IndexPath(item: 999, section: 0), at: .right, animated: false)
        keyboard.layoutIfNeeded()
        CATransaction.flush()
        XCTAssertNotNil(button("candidate-999", in: keyboard))
        XCTAssertTrue(topAnimations().isEmpty, "Reused candidate text must not fade after scrolling: \(topAnimations())")
    }

    @MainActor
    func testLargeCandidateScrollingPerformance() throws {
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "scroll", entries: ["a": (0..<1000).map { "候選\($0)" }]))
        keyboard.layoutIfNeeded()
        try XCTUnwrap(button("key-a", in: keyboard)).sendActions(for: .touchUpInside)
        keyboard.layoutIfNeeded()
        let collection = try XCTUnwrap(descendant(UICollectionView.self, in: keyboard))
        report("candidate_1000_scroll_end_start") {
            for index in [999, 0] {
                collection.scrollToItem(at: IndexPath(item: index, section: 0), at: .left, animated: false)
                keyboard.layoutIfNeeded()
            }
        }
        XCTAssertNotNil(button("candidate-0", in: keyboard))
    }

    @MainActor
    private func makeKeyboard() -> KeyboardView {
        let keyboard = KeyboardView(frame: CGRect(x: 0, y: 0, width: 393,
            height: KeyboardView.preferredHeight(width: 393, compact: false)))
        return keyboard
    }

    @MainActor
    private func descendant<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        if let match = view as? T { return match }
        return view.subviews.lazy.compactMap { self.descendant(type, in: $0) }.first
    }

    @MainActor
    private func textLabel(_ id: String, in view: UIView) -> UILabel? {
        if let label = view as? UILabel, label.accessibilityIdentifier == id { return label }
        return view.subviews.lazy.compactMap { self.textLabel(id, in: $0) }.first
    }

    @MainActor
    private func button(_ id: String, in view: UIView) -> UIButton? {
        if let button = view as? UIButton, button.accessibilityIdentifier == id { return button }
        return view.subviews.lazy.compactMap { self.button(id, in: $0) }.first
    }
}
