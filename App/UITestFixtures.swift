#if DEBUG
import Foundation

/// In-memory practice fixtures only; the extension always uses its bundled table.
enum UITestFixtures {
    static var table: CodeTable? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-testing") else { return nil }
        let candidates = arguments.contains("--many-candidates")
            ? (0..<1000).map { "候選\($0)" } : ["甲", "乙"]
        return CodeTable(name: "測試用人工字表", entries: ["a": candidates, "ab": ["測試"], ",,": ["，"]])
    }
}
#endif
