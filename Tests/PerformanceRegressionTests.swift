import XCTest
import UIKit

final class PerformanceRegressionTests: XCTestCase {
    @MainActor
    func testPairedPerformance() throws {
        let current = makeKeyboard()
        let baseline = BaselineKeyboardView(frame: current.frame)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(baseline)
        root.view.addSubview(current)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        func paired(_ name: String, repetitions: Int = 20, old: () -> Void, new: () -> Void) {
            for _ in 0..<10 { old(); new() }
            var before: [Double] = [], after: [Double] = [], ratios: [Double] = []
            func sample(_ operation: () -> Void) -> Double {
                let start = CACurrentMediaTime()
                for _ in 0..<repetitions { operation() }
                return (CACurrentMediaTime() - start) * 1000 / Double(repetitions)
            }
            for index in 0..<41 {
                let a: Double, b: Double
                if index.isMultiple(of: 2) { a = sample(old); b = sample(new) }
                else { b = sample(new); a = sample(old) }
                before.append(a); after.append(b); ratios.append(b / a)
            }
            before.sort(); after.sort(); ratios.sort()
            let medianRatio = ratios[20]
            let p95Ratio = after[38] / before[38]
            print("PERF_COMPARE \(name) baseline_median_ms=\(before[20]) current_median_ms=\(after[20]) baseline_p95_ms=\(before[38]) current_p95_ms=\(after[38]) paired_median_ratio=\(medianRatio) p95_ratio=\(p95Ratio)")
            let samples = ["baseline": before, "current": after, "pairedRatios": ratios]
            let data = try! JSONSerialization.data(withJSONObject: samples, options: [.sortedKeys])
            print("PERF_SAMPLES \(name) \(String(decoding: data, as: UTF8.self))")
        }
        for count in [7, 1000] {
            let table = CodeTable(name: "paired", entries: ["a": (0..<count).map { "候選\($0)" }])
            baseline.load(table: BaselineCodeTable(name: table.name, entries: table.entries)); current.load(table: table)
            baseline.layoutIfNeeded(); current.layoutIfNeeded(); CATransaction.flush()
            let oldA = try XCTUnwrap(button("key-a", in: baseline)), oldDelete = try XCTUnwrap(button("delete", in: baseline))
            let newA = try XCTUnwrap(button("key-a", in: current)), newDelete = try XCTUnwrap(button("delete", in: current))
            oldA.sendActions(for: .touchUpInside); newA.sendActions(for: .touchUpInside)
            XCTAssertEqual(baseline.engine.code, "a"); XCTAssertEqual(current.engine.code, "a")
            XCTAssertEqual(baseline.engine.candidates.count, count); XCTAssertEqual(current.engine.candidates.count, count)
            oldDelete.sendActions(for: .touchUpInside); newDelete.sendActions(for: .touchUpInside)
            XCTAssertTrue(baseline.engine.code.isEmpty); XCTAssertTrue(current.engine.code.isEmpty)
            paired("visible_candidate_\(count)_type_delete", old: {
                oldA.sendActions(for: .touchUpInside); baseline.layoutIfNeeded(); CATransaction.flush()
                oldDelete.sendActions(for: .touchUpInside); baseline.layoutIfNeeded(); CATransaction.flush()
            }, new: {
                newA.sendActions(for: .touchUpInside); current.layoutIfNeeded(); CATransaction.flush()
                newDelete.sendActions(for: .touchUpInside); current.layoutIfNeeded(); CATransaction.flush()
            })
        }
        let changing = CodeTable(name: "paired changing", entries: [
            "a": (0..<1000).map { "候選\($0)" }, "ab": (0..<1000).map { "第二\($0)" }
        ])
        baseline.load(table: BaselineCodeTable(name: changing.name, entries: changing.entries)); current.load(table: changing)
        let oldChanging = try ["key-a", "key-b", "delete", "delete"].map { try XCTUnwrap(button($0, in: baseline)) }
        let newChanging = try ["key-a", "key-b", "delete", "delete"].map { try XCTUnwrap(button($0, in: current)) }
        for key in oldChanging.prefix(2) { key.sendActions(for: .touchUpInside) }
        for key in newChanging.prefix(2) { key.sendActions(for: .touchUpInside) }
        XCTAssertEqual(baseline.engine.candidates.first, "第二0"); XCTAssertEqual(current.engine.candidates.first, "第二0")
        for key in oldChanging.suffix(2) { key.sendActions(for: .touchUpInside) }
        for key in newChanging.suffix(2) { key.sendActions(for: .touchUpInside) }
        paired("visible_changing_candidate_lists_1000", old: {
            for key in oldChanging { key.sendActions(for: .touchUpInside); baseline.layoutIfNeeded(); CATransaction.flush() }
        }, new: {
            for key in newChanging { key.sendActions(for: .touchUpInside); current.layoutIfNeeded(); CATransaction.flush() }
        })
        let table = try XCTUnwrap(TableStore.bundled(in: Bundle(for: Self.self)))
        baseline.load(table: BaselineCodeTable(name: table.name, entries: table.entries)); current.load(table: table)
        let oldKeys = try ["key-h", "key-x", "space", "key-a", "space"].map { try XCTUnwrap(button($0, in: baseline)) }
        let newKeys = try ["key-h", "key-x", "space", "key-a", "space"].map { try XCTUnwrap(button($0, in: current)) }
        var oldText = "", newText = ""
        baseline.onOutput = { if case .insert(let word) = $0 { oldText += word } }
        current.onOutput = { if case .insert(let word) = $0 { newText += word } }
        paired("visible_real_dictionary_hx_a", old: {
            oldText = ""
            for key in oldKeys { key.sendActions(for: .touchUpInside); baseline.layoutIfNeeded(); CATransaction.flush() }
        }, new: {
            newText = ""
            for key in newKeys { key.sendActions(for: .touchUpInside); current.layoutIfNeeded(); CATransaction.flush() }
        })
        XCTAssertEqual(oldText, "愛對")
        XCTAssertEqual(newText, "愛對")
        let oldTable = BaselineCodeTable(name: table.name, entries: table.entries)
        paired("visible_cold_first_type_after_table_load", repetitions: 5, old: {
            baseline.load(table: oldTable)
            oldKeys[0].sendActions(for: .touchUpInside)
            baseline.layoutIfNeeded(); CATransaction.flush()
        }, new: {
            current.load(table: table)
            newKeys[0].sendActions(for: .touchUpInside)
            current.layoutIfNeeded(); CATransaction.flush()
        })
        XCTAssertEqual(baseline.engine.code, "h"); XCTAssertEqual(current.engine.code, "h")
        XCTAssertEqual(baseline.engine.candidates, current.engine.candidates)
        baseline.clearComposition(); current.clearComposition()
        let oldPage = try XCTUnwrap(button("symbols", in: baseline))
        let newPage = try XCTUnwrap(button("symbols", in: current))
        paired("visible_symbol_toggle_pair", repetitions: 5, old: {
            for _ in 0..<2 { oldPage.sendActions(for: .touchUpInside); baseline.layoutIfNeeded(); CATransaction.flush() }
        }, new: {
            for _ in 0..<2 { newPage.sendActions(for: .touchUpInside); current.layoutIfNeeded(); CATransaction.flush() }
        })
        XCTAssertNotNil(button("key-a", in: baseline)); XCTAssertNotNil(button("key-a", in: current))
        let oldMode = try XCTUnwrap(button("mode", in: baseline))
        let newMode = try XCTUnwrap(button("globe", in: current))
        let oldA = try XCTUnwrap(button("key-a", in: baseline))
        let newA = try XCTUnwrap(button("key-a", in: current))
        let oldDelete = try XCTUnwrap(button("delete", in: baseline))
        let newDelete = try XCTUnwrap(button("delete", in: current))
        paired("visible_english_once_type_delete", old: {
            oldText = ""
            for key in [oldMode, oldA, oldDelete, oldMode] {
                key.sendActions(for: .touchUpInside); baseline.layoutIfNeeded(); CATransaction.flush()
            }
        }, new: {
            newText = ""
            for key in [newMode, newA, newDelete, newMode] {
                key.sendActions(for: .touchUpInside); current.layoutIfNeeded(); CATransaction.flush()
            }
        })
        XCTAssertEqual(oldText, "A"); XCTAssertEqual(newText, "A")
        XCTAssertEqual(baseline.engine.mode, .chinese); XCTAssertEqual(current.engine.mode, .chinese)
        print("PERF_SEMANTICS passed")
    }

    @MainActor
    func testHiddenCompositionReturnsWithCorrectErrorText() throws {
        let keyboard = makeKeyboard()
        keyboard.load(table: CodeTable(name: "probe", entries: ["a": ["甲"]]))
        try XCTUnwrap(button("key-a", in: keyboard)).sendActions(for: .touchUpInside)
        try XCTUnwrap(button("space", in: keyboard)).sendActions(for: .touchUpInside)
        XCTAssertFalse(keyboard.isShowingComposition)
        keyboard.loadError = "probe error"
        try XCTUnwrap(button("globe", in: keyboard)).sendActions(for: .touchUpInside)
        XCTAssertTrue(keyboard.isShowingComposition)
        func label(in view: UIView) -> UILabel? {
            if let label = view as? UILabel, label.accessibilityIdentifier == "composition-text" { return label }
            return view.subviews.lazy.compactMap { label(in: $0) }.first
        }
        XCTAssertEqual(label(in: keyboard)?.text, "!")
        XCTAssertEqual(button("composition", in: keyboard)?.accessibilityValue, "")
    }

    @MainActor
    private func makeKeyboard() -> KeyboardView {
        KeyboardView(frame: CGRect(x: 0, y: 0, width: 393, height: KeyboardView.preferredHeight(width: 393, compact: false)))
    }
    @MainActor
    private func button(_ id: String, in view: UIView) -> UIButton? {
        if let button = view as? UIButton, button.accessibilityIdentifier == id { return button }
        return view.subviews.lazy.compactMap { self.button(id, in: $0) }.first
    }
}
