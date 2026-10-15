import XCTest
import UIKit

final class ActivationTests: XCTestCase {
    @MainActor
    func testActivationMainThreadWorkStaysWithin100Milliseconds() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "boshiamy", withExtension: "bin"))
        var elapsed: [Double] = []
        for _ in 0..<21 {
            let start = ProcessInfo.processInfo.systemUptime
            let controller = KeyboardViewController()
            controller.tableProvider = { try? PackedCodeTable.decode(Data(contentsOf: url)) }
            controller.loadViewIfNeeded()
            controller.viewWillAppear(false)
            controller.view.frame = CGRect(x: 0, y: 0, width: 393, height: 310)
            controller.view.layoutIfNeeded()
            CATransaction.flush()
            elapsed.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
            let keyboard = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? KeyboardView }.first)
            _ = keyboard.engine.type("a")
            XCTAssertEqual(keyboard.engine.space(), .insert("對"))
        }
        XCTAssertTrue(elapsed.allSatisfy { $0.isFinite && $0 > 0 && $0 <= 100 }, "App-owned activation, including a fresh real dictionary decode: \(elapsed)")
        let data = try JSONSerialization.data(withJSONObject: ["scope": "Controller construction + fresh dictionary decode + view activation + layout + transaction flush; excludes iOS switching and physical display", "milliseconds": elapsed])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "keyboard-activation-main-thread"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testReactivationKeepsInstalledDictionaryAndCancelsComposition() throws {
        let table = try XCTUnwrap(TableStore.bundled(in: Bundle(for: Self.self)))
        let controller = KeyboardViewController()
        var loads = 0
        controller.tableProvider = { loads += 1; return table }
        controller.loadViewIfNeeded()
        let keyboard = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? KeyboardView }.first)
        controller.viewWillAppear(false)
        XCTAssertEqual(loads, 1)
        var samples: [Double] = []
        for _ in 0..<41 {
            _ = keyboard.engine.type("h")
            _ = keyboard.engine.type("x")
            XCTAssertEqual(keyboard.engine.candidates.first, "愛")
            controller.viewWillDisappear(false)
            let start = ProcessInfo.processInfo.systemUptime
            controller.viewWillAppear(false)
            keyboard.layoutIfNeeded()
            CATransaction.flush()
            samples.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
            XCTAssertTrue(keyboard.engine.code.isEmpty)
            XCTAssertEqual(keyboard.engine.space(), .insert(" "))
            _ = keyboard.engine.type("a")
            XCTAssertEqual(keyboard.engine.space(), .insert("對"))
        }
        XCTAssertEqual(loads, 1, "Reactivation must not reinstall the bundled dictionary or invalidate candidate caches")
        XCTAssertTrue(samples.allSatisfy { $0.isFinite && $0 > 0 && $0 <= 100 }, "App-owned reactivation budget; excludes system switching: \(samples)")
        let data = try JSONSerialization.data(withJSONObject: ["scope": "App-owned viewWillAppear + layout + transaction flush; excludes iOS and touch delivery", "milliseconds": samples])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "keyboard-reactivation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
