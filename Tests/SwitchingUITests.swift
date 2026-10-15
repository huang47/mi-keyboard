import XCTest

final class KeyboardSwitchUITests: XCTestCase {
    private enum SwitchKeyboard: String, CaseIterable {
        case mi, english, emoji

        var menuPredicate: NSPredicate {
            switch self {
            case .mi: return NSPredicate(format: "label == %@", "米鍵盤")
            case .english: return NSPredicate(format: "label BEGINSWITH[c] %@", "English")
            case .emoji: return NSPredicate(format: "label BEGINSWITH[c] %@", "Emoji")
            }
        }

        func ready(in app: XCUIApplication) -> Bool {
            switch self {
            case .mi: return app.buttons["key-a"].exists && app.buttons["key-a"].isHittable
            case .english:
                let q = app.keys.matching(NSPredicate(format: "label == 'q' OR label == 'Q'")).firstMatch
                return !app.buttons["key-a"].exists && q.exists && q.isHittable
            case .emoji:
                let search = app.descendants(matching: .any).matching(
                    NSPredicate(format: "label == %@ OR placeholderValue == %@", "Search Emoji", "Search Emoji")).firstMatch
                return search.exists && search.isHittable
            }
        }
    }

    private func threeKeyboardHost() -> XCUIApplication {
        // Use a dedicated simulator: these are real enabled system keyboards, not app fixtures.
        if !(UserDefaults.standard.stringArray(forKey: "AppleKeyboards") ?? []).contains("com.shh.boshiamy.keyboard") {
            let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
            settings.launch()
            for _ in 0..<3 { settings.swipeDown() }
            tapSetting(["General", "一般"], in: settings)
            tapSetting(["Keyboard", "鍵盤"], in: settings)
            settings.cells["KEYBOARDS"].tap()
            settings.cells["AddNewKeyboard"].tap()
            let entry = settings.cells.containing(.staticText, identifier: "米鍵盤").firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            entry.tap()
            settings.terminate()
            UserDefaults.standard.synchronize()
        }
        let enabled = UserDefaults.standard.stringArray(forKey: "AppleKeyboards") ?? []
        XCTAssertEqual(enabled.count, 3, "Enable exactly English (US), Emoji and 米鍵盤: \(enabled)")
        XCTAssertTrue(enabled.contains { $0.hasPrefix("en_US@") })
        XCTAssertTrue(enabled.contains { $0.hasPrefix("emoji@") })
        XCTAssertTrue(enabled.contains("com.shh.boshiamy.keyboard"))
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Continue"].waitForExistence(timeout: 2) && app.buttons["Continue"].isHittable {
            app.buttons["Continue"].tap() // First-use system keyboard tutorial; never part of a sample.
        }
        XCTAssertNotNil(observedKeyboard(in: app, among: SwitchKeyboard.allCases), app.debugDescription)
        return app
    }

    private func switchMenu(in app: XCUIApplication) throws {
        // Emoji exposes an ABC key with the same label as the bottom system globe.
        // Choose the lowest visible frame, not the first accessibility match. The
        // cross-process system control can report isHittable=false despite being visible.
        let controls = app.buttons.matching(NSPredicate(format: "label == %@", "Next keyboard"))
            .allElementsBoundByIndex.filter { $0.frame.width > 0 && $0.frame.height > 0 }
        let globe = try XCTUnwrap(controls.max(by: { $0.frame.minY < $1.frame.minY }), app.debugDescription)
        XCTAssertGreaterThan(globe.frame.minY, app.frame.height * 0.8)
        globe.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.2)
        _ = try switchMenuEntry(.mi, in: app) // A real picker, never a spacebar language label.
    }

    private func switchMenuEntry(_ keyboard: SwitchKeyboard, in app: XCUIApplication) throws -> XCUIElement {
        let deadline = ProcessInfo.processInfo.systemUptime + 3
        repeat {
            for type in [XCUIElement.ElementType.button, .staticText] {
                if let entry = app.descendants(matching: type).matching(keyboard.menuPredicate)
                    .allElementsBoundByIndex.last(where: {
                        $0.frame.minY > app.frame.height * 0.4 && $0.isHittable
                    }) { return entry }
            }
            Thread.sleep(forTimeInterval: 0.05)
        } while ProcessInfo.processInfo.systemUptime < deadline
        XCTFail("Missing actual keyboard-picker row \(keyboard.rawValue): \(app.debugDescription)")
        throw NSError(domain: "KeyboardSwitchUITests", code: 1)
    }

    private func observedKeyboard(in app: XCUIApplication, among candidates: [SwitchKeyboard]) -> SwitchKeyboard? {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        repeat {
            if let keyboard = candidates.first(where: { $0.ready(in: app) }),
               ProcessInfo.processInfo.systemUptime <= deadline { return keyboard }
            // Avoid the coarse predicate-expectation timer in latency measurements.
            Thread.sleep(forTimeInterval: 0.02)
        } while ProcessInfo.processInfo.systemUptime < deadline
        return nil
    }

    private func waitForKeyboard(_ keyboard: SwitchKeyboard, in app: XCUIApplication) {
        XCTAssertEqual(observedKeyboard(in: app, among: [keyboard]), keyboard, app.debugDescription)
    }

    private func selectKeyboard(_ keyboard: SwitchKeyboard, in app: XCUIApplication) throws {
        if keyboard.ready(in: app) { return }
        try switchMenu(in: app)
        try switchMenuEntry(keyboard, in: app).tap()
        if app.buttons["Continue"].exists && app.buttons["Continue"].isHittable { app.buttons["Continue"].tap() }
        waitForKeyboard(keyboard, in: app)
    }

    func testThreeKeyboardsPickerAndCompositionCancellation() throws {
        let app = threeKeyboardHost()
        let editor = app.textFields["switch-editor"]
        try selectKeyboard(.mi, in: app)
        try switchMenu(in: app)
        for keyboard in SwitchKeyboard.allCases {
            XCTAssertTrue(try switchMenuEntry(keyboard, in: app).isHittable)
        }
        recordScreen("Three-keyboard system picker")
        try switchMenuEntry(.mi, in: app).tap()
        waitForKeyboard(.mi, in: app)
        for destination in [SwitchKeyboard.english, .emoji] {
            app.buttons["key-h"].tap()
            app.buttons["key-x"].tap()
            try selectKeyboard(destination, in: app)
            XCTAssertEqual(editor.value as? String, "", "Switching must not commit the composition or a space")
            if destination == .english {
                app.keys.matching(NSPredicate(format: "label == 'a' OR label == 'A'")).firstMatch.tap()
                XCTAssertTrue(["a", "A"].contains(editor.value as? String ?? ""))
                try selectKeyboard(.mi, in: app)
                app.buttons["delete"].tap()
            }
            try selectKeyboard(.mi, in: app)
            XCTAssertFalse(app.buttons["composition"].isHittable)
            app.buttons["key-h"].tap()
            app.buttons["key-x"].tap()
            app.buttons["space"].tap()
            let inserted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "愛"), object: editor)
            XCTAssertEqual(XCTWaiter.wait(for: [inserted], timeout: 2), .completed)
            app.buttons["delete"].tap()
        }
        recordScreen("Three real keyboards: picker, native English, Emoji and composition cancellation")
        try selectKeyboard(.english, in: app)
    }

    func testThreeKeyboardsSwitchLatency() throws {
        let app = threeKeyboardHost()
        var samples: [[String: Any]] = []
        // Persist partial results on failure; a missing/timeout transition is never a success sample.
        defer {
            let report: [String: Any] = [
                "schemaVersion": 1,
                "environment": "iOS Simulator / XCTest / native UITextField host; not physical touch-to-display latency",
                "enabledKeyboards": UserDefaults.standard.stringArray(forKey: "AppleKeyboards") ?? [],
                "clock": "ProcessInfo.systemUptime (monotonic seconds)",
                "measurement": "Before XCTest action to target accessibility readiness; includes event injection, app-idle waits and AX polling. Picker-open/hold time excluded from picker-selection samples.",
                "samples": samples
            ]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "keyboard-switch-latency"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        func record(from: SwitchKeyboard, to: SwitchKeyboard, action: String, iteration: Int,
                    perform: () -> Void) {
            let start = ProcessInfo.processInfo.systemUptime
            perform()
            let returned = ProcessInfo.processInfo.systemUptime
            waitForKeyboard(to, in: app)
            let ready = ProcessInfo.processInfo.systemUptime
            let sample: [String: Any] = ["from": from.rawValue, "to": to.rawValue, "action": action,
                "iteration": iteration, "actionMilliseconds": (returned - start) * 1000,
                "readyMilliseconds": (ready - start) * 1000]
            samples.append(sample)
            let data = try! JSONSerialization.data(withJSONObject: sample, options: [.sortedKeys])
            print("KEYBOARD_SWITCH_SAMPLE " + String(decoding: data, as: UTF8.self))
        }
        // Warm every input mode and dismiss one-time system tutorials outside measurement.
        for keyboard in [SwitchKeyboard.english, .emoji, .mi, .english] {
            try selectKeyboard(keyboard, in: app)
        }
        // Same selection gesture for all six routes provides native-to-native controls.
        let routes: [(SwitchKeyboard, SwitchKeyboard)] = [(.english, .emoji), (.emoji, .english),
            (.english, .mi), (.mi, .english), (.emoji, .mi), (.mi, .emoji)]
        for (from, to) in routes {
            for iteration in 0..<5 {
                try selectKeyboard(from, in: app)
                try switchMenu(in: app)
                let entry = try switchMenuEntry(to, in: app)
                record(from: from, to: to, action: "pickerSelection", iteration: iteration) { entry.tap() }
            }
        }
        // Establish each native predecessor separately; never assume short tap always means English.
        for previous in [SwitchKeyboard.english, .emoji] {
            for iteration in 0..<5 {
                try selectKeyboard(previous, in: app)
                try selectKeyboard(.mi, in: app)
                XCTAssertFalse(app.buttons["composition"].isHittable)
                app.buttons["key-h"].tap()
                app.buttons["key-x"].tap()
                let start = ProcessInfo.processInfo.systemUptime
                app.buttons["globe"].tap()
                let returned = ProcessInfo.processInfo.systemUptime
                let destination = try XCTUnwrap(observedKeyboard(in: app, among: [.english, .emoji]), app.debugDescription)
                let ready = ProcessInfo.processInfo.systemUptime
                XCTAssertEqual(app.textFields["switch-editor"].value as? String, "",
                               "Embedded-globe switching must cancel composition without committing text")
                samples.append(["from": "mi", "to": destination.rawValue, "action": "shortTap",
                    "previousNative": previous.rawValue, "iteration": iteration,
                    "actionMilliseconds": (returned - start) * 1000,
                    "readyMilliseconds": (ready - start) * 1000])
            }
        }
        XCTAssertEqual(samples.count, 40)
        try selectKeyboard(.english, in: app)
    }

    /// Run after externally terminating the extension process; the JSON does not claim OS caches are cold.
    func testThreeKeyboardsFirstActivationLatency() throws {
        let app = threeKeyboardHost()
        try selectKeyboard(.english, in: app)
        try switchMenu(in: app)
        let entry = try switchMenuEntry(.mi, in: app)
        let start = ProcessInfo.processInfo.systemUptime
        entry.tap()
        let returned = ProcessInfo.processInfo.systemUptime
        waitForKeyboard(.mi, in: app)
        let ready = ProcessInfo.processInfo.systemUptime
        let sample: [String: Any] = ["from": "english", "to": "mi", "action": "pickerSelection",
            "measurement": "First observed Mi activation in this run; see external process-preparation evidence. OS caches are not asserted cold.",
            "actionMilliseconds": (returned - start) * 1000, "readyMilliseconds": (ready - start) * 1000]
        let data = try JSONSerialization.data(withJSONObject: sample, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "keyboard-first-activation-latency"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["key-a"].tap()
        app.buttons["space"].tap()
        XCTAssertEqual(app.textFields["switch-editor"].value as? String, "對")
        try selectKeyboard(.english, in: app)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            recordScreen("Switch failure: " + name)
            let tree = XCTAttachment(string: XCUIApplication().debugDescription)
            tree.lifetime = .keepAlways
            add(tree)
        }
        XCUIApplication().terminate()
    }

    private func recordScreen(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapSetting(_ labels: [String], in app: XCUIApplication) {
        for _ in 0..<5 {
            for label in labels {
                let cell = app.cells.containing(.staticText, identifier: label).firstMatch
                if cell.exists && cell.isHittable { cell.tap(); return }
            }
            app.swipeUp()
        }
        XCTFail("Missing setting \(labels): \(app.debugDescription)")
    }
}
