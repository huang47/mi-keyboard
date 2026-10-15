import XCTest

final class KeyboardUITests: XCTestCase {
    func testNativeEnglishLayoutReference() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-ui-testing"]
        app.launch()
        let editor = app.textViews["practice-editor"]
        focusHostEditor(editor, in: app)
        let globe = app.buttons["Next keyboard"]
        XCTAssertTrue(globe.waitForExistence(timeout: 5), app.debugDescription)
        globe.press(forDuration: 0.8)
        let englishName = NSPredicate(format: "label CONTAINS[c] %@", "English")
        let englishButton = app.buttons.matching(englishName).firstMatch
        if englishButton.exists && englishButton.isHittable { englishButton.tap() }
        else {
            let row = try XCTUnwrap(app.staticTexts.matching(englishName).allElementsBoundByIndex.last {
                $0.frame.minY > app.frame.height * 0.4 && $0.isHittable
            }, app.debugDescription)
            row.tap()
        }
        if app.staticTexts["Quickly Change Keyboards"].exists { app.buttons["Continue"].tap() }
        var nativeFrames: [Bool: [String: CGRect]] = [:]
        func capture(_ name: String) throws {
            let q = app.keys.matching(NSPredicate(format: "label == 'q' OR label == 'Q'")).firstMatch
            XCTAssertTrue(q.waitForExistence(timeout: 5), app.debugDescription)
            var keys: [[String: Any]] = []
            var frames: [String: CGRect] = [:]
            for key in app.keyboards.firstMatch.descendants(matching: .any).allElementsBoundByIndex
                where key.elementType == .key || key.elementType == .button {
                let f = key.frame
                if f.height > 0 { frames[key.label.lowercased()] = f }
                keys.append(["label": key.label, "type": key.elementType.rawValue,
                             "x": f.minX, "y": f.minY, "width": f.width, "height": f.height])
            }
            nativeFrames[name.hasPrefix("landscape")] = frames
            let data = try JSONSerialization.data(withJSONObject: ["name": name,
                "screenWidth": app.frame.width, "screenHeight": app.frame.height,
                "keys": keys], options: [.prettyPrinted, .sortedKeys])
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "Native English frames \(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            recordScreen("Native English reference \(name)")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "Native English accessibility \(name)"
            tree.lifetime = .keepAlways
            add(tree)
        }
        try capture("portrait-uppercase")
        app.keys.matching(NSPredicate(format: "label == 'a' OR label == 'A'")).firstMatch.tap()
        try capture("portrait-lowercase")
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        try capture("landscape-lowercase")
        app.buttons["shift"].tap()
        try capture("landscape-uppercase")
        XCUIDevice.shared.orientation = .portrait
        expectation(for: NSPredicate { _, _ in app.frame.width < app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        app.buttons["Next keyboard"].press(forDuration: 0.8)
        let names = NSPredicate(format: "label CONTAINS %@", "米鍵盤")
        let menuButton = app.buttons.matching(names).firstMatch
        if menuButton.exists && menuButton.isHittable { menuButton.tap() }
        else {
            let row = try XCTUnwrap(app.staticTexts.matching(names).allElementsBoundByIndex.last {
                $0.frame.minY > app.frame.height * 0.4 && $0.isHittable
            }, app.debugDescription)
            row.tap()
        }
        XCTAssertTrue(app.buttons["key-q"].waitForExistence(timeout: 5))
        for compact in [false, true] {
            if compact {
                XCUIDevice.shared.orientation = .landscapeLeft
                expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
                waitForExpectations(timeout: 5)
            }
            assertKeyboardGeometry(in: app)
            let nativeQ = try XCTUnwrap(nativeFrames[compact]?["q"])
            let actual = app.buttons["key-q"].frame
            print("NATIVE_ABSOLUTE_POSITION compact=\(compact) nativeQ=\(nativeQ.minY + 1) customQ=\(actual.minY)")
            XCTAssertEqual(actual.minY, nativeQ.minY + 1, accuracy: 0.5)
            recordScreen(compact ? "Matched native landscape plus numbers" : "Matched native portrait plus numbers")
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testHeldCharacterCommitsOnceAndDraggingOutCancels() {
        let app = launchPractice()
        app.buttons["globe"].tap()
        let a = app.buttons["key-a"]
        a.press(forDuration: 1)
        XCTAssertEqual(app.staticTexts["practice-output"].label, "A")
        let start = a.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let outside = app.staticTexts["practice-output"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: outside)
        XCTAssertEqual(app.staticTexts["practice-output"].label, "A")
        a.tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "Aa")
        app.buttons["symbols"].tap()
        app.buttons["key-/"].press(forDuration: 0.8)
        XCTAssertEqual(app.staticTexts["practice-output"].label, "Aa/")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testPrivacyPolicyIsAccessibleOffline() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-ui-testing"]
        app.launch()
        let policy = app.buttons["open-privacy-policy"]
        for _ in 0..<4 where !policy.isHittable { app.swipeUp() }
        XCTAssertTrue(policy.isHittable)
        policy.tap()
        XCTAssertTrue(app.staticTexts["privacy-section-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["privacy-section-0"].label.contains("不儲存輸入紀錄"))
        for index in 1...4 { reveal(app.staticTexts["privacy-section-\(index)"], in: app) }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["open-privacy-policy"].exists)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "App privacy policy"
        image.lifetime = .keepAlways
        add(image)
    }

    func testLargeCandidateListSwipesSelectsAndRotates() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--many-candidates"]
        app.launch()
        let practice = app.buttons["open-practice"]
        if !practice.isHittable { app.swipeUp() }
        practice.tap()
        app.buttons["key-a"].tap()
        let list = app.collectionViews["candidate-list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["candidate-0"].isHittable)
        list.swipeLeft()
        let candidate = try XCTUnwrap(list.buttons.allElementsBoundByIndex.first {
            $0.isHittable && $0.identifier != "candidate-0"
        })
        let index = try XCTUnwrap(Int(candidate.identifier.dropFirst("candidate-".count)))
        XCTAssertGreaterThan(index, 0)
        candidate.tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "候選\(index)")
        app.buttons["key-a"].tap()
        XCTAssertTrue(app.buttons["candidate-0"].isHittable)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(list.frame.height, 30, accuracy: 1)
        list.swipeLeft()
        let visible = try XCTUnwrap(list.buttons.allElementsBoundByIndex.first { $0.isHittable })
        let rotatedIndex = try XCTUnwrap(Int(visible.identifier.dropFirst("candidate-".count)))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Large candidate list after landscape swipe"
        attachment.lifetime = .keepAlways
        add(attachment)
        visible.tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "候選\(index)候選\(rotatedIndex)")
        app.terminate()
        app.launchArguments = ["--reset-ui-testing"]
        app.launch()
    }

    func testKeyGutterTouchesInsertExactlyOnceAndCompositionKeepsKeysStationary() {
        let app = launchPractice()
        app.buttons["globe"].tap()
        app.buttons["shift"].tap() // Explicit lowercase mode.
        let q = app.buttons["key-q"]
        q.coordinate(withNormalizedOffset: CGVector(dx: 1.06, dy: 0.5)).tap()
        q.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.10)).tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "qq")
        app.buttons["globe"].tap()
        let restingFrame = q.frame
        app.buttons["key-a"].tap()
        XCTAssertEqual(q.frame, restingFrame)
        app.buttons["space"].tap()
        XCTAssertEqual(q.frame, restingFrame)
        XCTAssertEqual(app.staticTexts["practice-output"].label, "qq甲")
    }

    func testNumberRowAndNativeStyleGeometry() {
        let app = launchPractice()
        assertKeyboardGeometry(in: app)
        XCTAssertEqual(app.buttons["key-q"].label, "Q")
        XCTAssertEqual(app.buttons["key-f"].label, "F")
        XCTAssertEqual(app.buttons["symbols"].label, "123")
        XCTAssertEqual(app.buttons["return"].label, "換行")
        XCTAssertFalse(app.buttons["composition"].isHittable)
        let idle = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        idle.name = "Native layout plus numbers portrait"
        idle.lifetime = .keepAlways
        add(idle)
        app.buttons["key-a"].tap()
        app.buttons["key-2"].tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "乙")
        app.buttons["globe"].tap()
        app.buttons["shift"].tap()
        app.buttons["key-1"].tap()
        app.buttons["key-2"].press(forDuration: 0.7)
        app.buttons["key-1"].press(forDuration: 0.7)
        app.buttons["key-q"].tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "乙1,.q")
        app.buttons["globe"].tap()
        app.buttons["key-2"].press(forDuration: 0.7)
        XCTAssertEqual(app.buttons["composition"].value as? String, ",")
        app.buttons["delete"].tap()
        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "Number row portrait"
        portrait.lifetime = .keepAlways
        add(portrait)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        assertKeyboardGeometry(in: app)
        XCTAssertTrue(app.buttons["key-0"].isHittable)
        XCTAssertTrue(app.staticTexts["practice-output"].isHittable)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Number row landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
    }

    private func assertKeyboardGeometry(in app: XCUIApplication) {
        struct Fixture: Decodable {
            struct Rectangle: Decodable { let x, y, width, height: CGFloat }
            struct Key: Decodable { let label: String; let cap: Rectangle }
            struct Capture: Decodable { let name: String; let screenWidth: CGFloat; let keys: [Key] }
            let captures: [Capture]
        }
        guard let url = Bundle(for: Self.self).url(forResource: "NativeEnglishKeyFrames", withExtension: "json"),
              let data = try? Data(contentsOf: url), let fixture = try? JSONDecoder().decode(Fixture.self, from: data),
              let capture = fixture.captures.first(where: { abs($0.screenWidth - app.frame.width) < 1 && $0.name.hasSuffix("uppercase") }),
              let nativeQ = capture.keys.first(where: { $0.label == "Q" }) else {
            XCTFail("Missing independent native keyboard measurement for \(app.frame.width)"); return
        }
        let q = app.buttons["key-q"].frame
        for key in capture.keys {
            let id: String
            switch key.label {
            case "shift", "delete", "return": id = key.label
            case "numbers": id = "symbols"
            case "Emoji": id = "globe"
            case " ": id = "space"
            default: id = "key-" + key.label.lowercased()
            }
            let control = app.buttons[id]
            XCTAssertTrue(control.isHittable, id)
            let frame = control.frame
            XCTAssertEqual(frame.minX, key.cap.x, accuracy: 0.5, id)
            XCTAssertEqual(frame.minY - q.minY, key.cap.y - nativeQ.cap.y, accuracy: 0.5, id)
            XCTAssertEqual(frame.width, key.cap.width, accuracy: 0.5, id)
            XCTAssertEqual(frame.height, key.cap.height, accuracy: 0.5, id)
        }
        for (digit, letter) in zip("1234567890", "qwertyuiop") {
            let number = app.buttons["key-\(digit)"].frame
            let character = app.buttons["key-\(letter)"].frame
            XCTAssertEqual(number.minX, character.minX, accuracy: 0.5)
            XCTAssertEqual(number.width, character.width, accuracy: 0.5)
            XCTAssertEqual(number.height, character.height, accuracy: 0.5)
            XCTAssertLessThan(number.maxY, character.minY)
        }
        XCTAssertFalse(app.buttons["mode"].exists)
        XCTAssertLessThan(app.buttons["globe"].frame.maxX, app.buttons["space"].frame.minX)
    }

    func testThreeShiftModesWithSingleAndDoubleTaps() {
        let app = launchPractice()
        app.buttons["globe"].tap()
        let shift = app.buttons["shift"]
        XCTAssertEqual(shift.value as? String, "下一個字母大寫")
        recordScreen("Shift once solid")
        app.buttons["key-a"].tap()
        app.buttons["key-b"].tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "Ab")
        XCTAssertEqual(shift.value as? String, "小寫")
        recordScreen("Shift off outline")
        shift.doubleTap()
        XCTAssertEqual(shift.value as? String, "鎖定大寫")
        app.buttons["key-c"].tap()
        app.buttons["key-d"].tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "AbCD")
        XCTAssertEqual(shift.value as? String, "鎖定大寫")
        recordScreen("Caps Lock solid underline")
        shift.tap()
        app.buttons["key-e"].tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "AbCDe")
        shift.tap()
        app.buttons["key-f"].tap()
        app.buttons["key-g"].tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "AbCDeFg")
    }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            recordScreen("Failure: " + name)
            let tree = XCTAttachment(string: XCUIApplication().debugDescription)
            tree.lifetime = .keepAlways
            add(tree)
        }
        XCUIDevice.shared.orientation = .portrait
        XCUIApplication().terminate()
    }

    private func recordScreen(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testHomophoneLookupLongPressSelectionBackspaceAndNormalTyping() throws {
        let app = launchPractice(["--reset-ui-testing"])
        app.buttons["key-9"].press(forDuration: 0.7)
        for key in ["m", "n", "f", "o"] { app.buttons["key-\(key)"].tap() }
        XCTAssertTrue(app.buttons["candidate-0"].label.contains("瞎"))
        app.buttons["space"].tap()
        XCTAssertEqual(app.buttons["composition"].value as? String, "'瞎")
        XCTAssertFalse(app.staticTexts["practice-output"].label.contains("瞎"))
        recordScreen("Offline homophone candidates for 瞎")
        app.buttons["delete"].tap()
        XCTAssertEqual(app.buttons["composition"].value as? String, "'mnfo")
        app.buttons["key-1"].tap()
        let list = app.collectionViews["candidate-list"]
        let shrimp = list.buttons.matching(NSPredicate(format: "label CONTAINS %@", "蝦")).firstMatch
        for _ in 0..<6 where !shrimp.isHittable { list.swipeLeft() }
        XCTAssertTrue(shrimp.isHittable, app.debugDescription)
        shrimp.tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "蝦")
        app.buttons["key-h"].tap(); app.buttons["key-x"].tap()
        app.buttons["space"].tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "蝦愛")
    }

    func testLandscapePracticeSymbolsAndUppercase() {
        let app = launchPractice()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        app.buttons["globe"].tap()
        expectation(for: NSPredicate(format: "label == %@", "A"), evaluatedWith: app.buttons["key-a"])
        waitForExpectations(timeout: 5)
        app.buttons["key-a"].tap()
        app.buttons["symbols"].tap()
        app.buttons["key-/"].tap()
        app.buttons["more-symbols"].tap()
        app.buttons["key-+"].tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "A/+")
        XCTAssertTrue(app.staticTexts["practice-output"].isHittable)
        XCTAssertTrue(app.buttons["space"].isHittable)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Landscape keyboard"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testPracticeCandidateSelectionDeletionAndModeSwitch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let practice = app.buttons["open-practice"]
        if !practice.isHittable { app.swipeUp() }
        XCTAssertTrue(practice.waitForExistence(timeout: 5))
        practice.tap()
        app.buttons["key-a"].tap()
        XCTAssertTrue(app.buttons["candidate-1"].waitForExistence(timeout: 3))
        app.buttons["candidate-1"].tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "乙")
        app.buttons["key-a"].tap()
        app.buttons["key-b"].tap()
        app.buttons["space"].tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "乙測試")
        app.buttons["delete"].tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "乙測")
        app.buttons["globe"].tap()
        app.buttons["key-a"].tap()
        app.buttons["symbols"].tap()
        app.buttons["key-1"].tap()
        XCTAssertEqual(app.staticTexts["practice-output"].label, "乙測A1")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Keyboard practice"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSystemKeyboardExtensionWithoutFullAccess() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-ui-testing"]
        app.launch()
        let enabled = UserDefaults.standard.stringArray(forKey: "AppleKeyboards") ?? []
        if !enabled.contains("com.shh.boshiamy.keyboard") {
            let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
            settings.launch()
            for _ in 0..<3 { settings.swipeDown() }
            tapSetting(["General", "一般"], in: settings)
            tapSetting(["Keyboard", "鍵盤"], in: settings)
            XCTAssertTrue(settings.cells["KEYBOARDS"].waitForExistence(timeout: 5))
            settings.cells["KEYBOARDS"].tap()
            settings.cells["AddNewKeyboard"].tap()
            let entry = settings.cells.containing(.staticText, identifier: "米鍵盤").firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            entry.tap()
        }
        // RequestsOpenAccess=false: never turn on Allow Full Access.
        app.activate()
        let editor = app.textViews["practice-editor"]
        // XCTest idles the host app; keyboard events and proxy updates run in another process.
        func assertText(_ expected: String, file: StaticString = #filePath, line: UInt = #line) {
            let committed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: editor)
            XCTAssertEqual(XCTWaiter.wait(for: [committed], timeout: 2), .completed, file: file, line: line)
            XCTAssertEqual(editor.value as? String, expected, file: file, line: line)
        }
        focusHostEditor(editor, in: app)
        // Establish native English as the previous keyboard; this simulator also has other input methods.
        let systemGlobe = app.buttons["Next keyboard"]
        XCTAssertTrue(systemGlobe.waitForExistence(timeout: 5))
        systemGlobe.press(forDuration: 0.8)
        let englishName = NSPredicate(format: "label CONTAINS[c] %@", "English")
        let englishButton = app.buttons.matching(englishName).firstMatch
        if englishButton.exists && englishButton.isHittable { englishButton.tap() }
        else {
            let englishRow = app.staticTexts.matching(englishName).allElementsBoundByIndex.last { $0.frame.minY > app.frame.height * 0.4 && $0.isHittable }
            XCTAssertNotNil(englishRow, app.debugDescription)
            englishRow?.tap()
        }
        if app.staticTexts["Quickly Change Keyboards"].exists { app.buttons["Continue"].tap() }
        if !app.buttons["key-a"].waitForExistence(timeout: 2) {
            let next = app.buttons["Next keyboard"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.press(forDuration: 0.8)
            let names = NSPredicate(format: "label CONTAINS %@", "米鍵盤")
            let menuButton = app.buttons.matching(names).firstMatch
            if menuButton.exists && menuButton.isHittable { menuButton.tap() }
            else {
                let rows = app.staticTexts.matching(names).allElementsBoundByIndex
                let row = rows.last { $0.frame.minY > app.frame.height * 0.4 && $0.isHittable }
                XCTAssertNotNil(row, app.debugDescription)
                row?.tap()
            }
        }
        XCTAssertTrue(app.buttons["key-a"].waitForExistence(timeout: 5))
        // Exercise the globe inside the spacebar, even when iOS has a second globe below.
        let embeddedGlobe = app.buttons["globe"]
        XCTAssertTrue(embeddedGlobe.isHittable, "The embedded globe must remain interactive when iOS supplies its own switch key")
        guard embeddedGlobe.isHittable else { return }
        for cycle in 1...3 {
            app.buttons["key-h"].tap()
            app.buttons["key-x"].tap()
            let switchKey = embeddedGlobe
            switchKey.tap()
            if app.staticTexts["Quickly Change Keyboards"].exists { app.buttons["Continue"].tap() }
            let nativeQ = app.keys.matching(NSPredicate(format: "label == %@ OR label == %@", "q", "Q")).firstMatch
            XCTAssertTrue(nativeQ.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertFalse(app.buttons["key-a"].exists)
            assertText("") // Switching must cancel composition, never commit a word or space.
            recordScreen("Globe to native English \(cycle)")
            let nativeGlobe = app.buttons["Next keyboard"]
            XCTAssertTrue(nativeGlobe.isHittable, app.debugDescription)
            nativeGlobe.tap()
            XCTAssertTrue(app.buttons["key-a"].waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertFalse(app.buttons["composition"].isHittable)
            assertText("")
        }
        // Long press still offers the system keyboard picker rather than inserting a space.
        app.buttons["globe"].press(forDuration: 0.8)
        let menuName = NSPredicate(format: "label CONTAINS %@", "米鍵盤")
        let menuButton = app.buttons.matching(menuName).firstMatch
        if menuButton.exists && menuButton.isHittable { menuButton.tap() }
        else {
            let menuRow = app.staticTexts.matching(menuName).allElementsBoundByIndex.last { $0.frame.minY > app.frame.height * 0.4 && $0.isHittable }
            XCTAssertNotNil(menuRow, app.debugDescription)
            menuRow?.tap()
        }
        XCTAssertTrue(app.buttons["key-a"].waitForExistence(timeout: 5))
        assertKeyboardGeometry(in: app)
        let restingFrame = app.buttons["key-q"].frame
        app.buttons["key-a"].tap()
        XCTAssertEqual(app.buttons["key-q"].frame, restingFrame)
        app.buttons["space"].tap()
        XCTAssertEqual(app.buttons["key-q"].frame, restingFrame)
        assertText("對")
        app.buttons["key-h"].tap()
        app.buttons["key-x"].tap()
        app.buttons["space"].tap()
        assertText("對愛")
        app.buttons["delete"].tap()
        assertText("對")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "System keyboard extension"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Real extension: resolving the seed must not insert it into the host editor.
        app.buttons["key-9"].press(forDuration: 0.7)
        for key in ["m", "n", "f", "o"] { app.buttons["key-\(key)"].tap() }
        app.buttons["space"].tap()
        assertText("對")
        XCTAssertEqual(app.buttons["composition"].value as? String, "'瞎")
        let homophoneList = app.collectionViews["candidate-list"]
        let shrimp = homophoneList.buttons.matching(NSPredicate(format: "label CONTAINS %@", "蝦")).firstMatch
        for _ in 0..<6 where !shrimp.isHittable { homophoneList.swipeLeft() }
        XCTAssertTrue(shrimp.isHittable, app.debugDescription)
        recordScreen("System extension homophone lookup without Full Access")
        shrimp.tap()
        assertText("對蝦")
        app.buttons["delete"].tap()
        assertText("對")

        assertKeyboardGeometry(in: app)
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        assertKeyboardGeometry(in: app)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "System number row landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        XCUIDevice.shared.orientation = .portrait
        expectation(for: NSPredicate { _, _ in app.frame.width < app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)

        // The globe must leave the extension and use the actual system English keyboard.
        app.buttons["globe"].tap()
        let nativeA = app.keys.matching(NSPredicate(format: "label == %@ OR label == %@", "a", "A")).firstMatch
        XCTAssertTrue(nativeA.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["key-a"].exists)
        nativeA.tap()
        let nativeText = editor.value as? String ?? ""
        XCTAssertTrue(nativeText == "對a" || nativeText == "對A", nativeText)
        recordScreen("Globe native English typing")
        app.buttons["Next keyboard"].tap()
        XCTAssertTrue(app.buttons["key-a"].waitForExistence(timeout: 5))
        app.buttons["delete"].tap()
        assertText("對")

        // Practice fixtures are in memory only; the extension always uses its bundled table.
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        focusHostEditor(editor, in: app)
        XCTAssertTrue(app.buttons["key-a"].waitForExistence(timeout: 5))
        app.buttons["key-a"].tap()
        app.buttons["space"].tap()
        assertText("對")
        app.terminate()
        app.launchArguments = ["--reset-ui-testing"]
        app.launch()
    }

    private func tapSetting(_ labels: [String], in app: XCUIApplication) {
        for _ in 0..<5 {
            for label in labels {
                let cell = app.cells.containing(.staticText, identifier: label).firstMatch
                if cell.exists && cell.frame.origin.x.isFinite && cell.frame.origin.y.isFinite && cell.isHittable {
                    cell.tap(); return
                }
            }
            app.swipeUp()
        }
        XCTFail("Missing setting \(labels): \(app.debugDescription)")
    }

    func testInvalidCompositionStaysEditable() {
        let app = launchPractice()
        app.buttons["key-z"].tap()
        app.buttons["space"].tap()
        XCTAssertEqual(app.buttons["composition"].value as? String, "z")
        app.buttons["composition"].press(forDuration: 0.7)
        XCTAssertEqual(app.staticTexts["practice-output"].label, "z")
        app.buttons["key-a"].tap()
        app.buttons["delete"].tap()
        XCTAssertFalse(app.buttons["composition"].isHittable)
    }
}

// Behavioral coverage crosses the same UIKit controls and Files picker as users.
// Fixtures only seed dictionaries; they do not bypass parsing or keyboard actions.
extension KeyboardUITests {
    private func launchPractice(_ arguments: [String] = ["--ui-testing"]) -> XCUIApplication {
        let app = launchHome(arguments)
        reveal(app.buttons["open-practice"], in: app)
        app.buttons["open-practice"].tap()
        XCTAssertTrue(app.buttons["key-a"].waitForExistence(timeout: 5))
        return app
    }

    private func launchHome(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func focusHostEditor(_ editor: XCUIElement, in app: XCUIApplication) {
        // A few visible pixels can make isHittable true without exposing a usable tap point.
        for _ in 0..<5 {
            let frame = editor.frame
            if editor.isHittable && frame.minY >= 120 && frame.maxY <= app.frame.maxY - 60 { break }
            if frame.minY < 120 { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(editor.isHittable)
        XCTAssertLessThanOrEqual(editor.frame.maxY, app.frame.maxY - 60)
        editor.tap()
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable {
            if element.exists && element.frame.midY < app.frame.midY { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func type(_ code: String, in app: XCUIApplication) {
        for character in code { app.buttons["key-\(character)"].tap() }
    }

    private func assertOutput(_ text: String, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        let expected = text.isEmpty ? "輸入字碼，點選候選字…" : text
        XCTAssertEqual(app.staticTexts["practice-output"].label, expected, file: file, line: line)
    }

    func testIdleSpaceReturnAndZeroInsertLiterals() {
        let app = launchPractice()
        app.buttons["key-0"].tap()
        app.buttons["space"].tap()
        app.buttons["return"].tap()
        app.buttons["key-1"].tap()
        assertOutput("0 \n1", in: app)
    }

    func testReturnCommitsFirstCandidateBeforeNewline() {
        let app = launchPractice()
        type("a", in: app)
        app.buttons["return"].tap()
        app.buttons["key-0"].tap()
        assertOutput("甲\n0", in: app)
        XCTAssertFalse(app.buttons["composition"].isHittable)
    }

    func testZeroCommitsCandidateButUnavailableNumberDoesNothing() {
        let app = launchPractice()
        type("a", in: app)
        app.buttons["key-9"].tap()
        XCTAssertEqual(app.buttons["composition"].value as? String, "a")
        assertOutput("", in: app)
        app.buttons["key-0"].tap()
        assertOutput("甲0", in: app)
    }

    func testCompositionLengthLimitAndBackspaceRecovery() {
        let app = launchPractice()
        type("aba", in: app)
        XCTAssertEqual(app.buttons["composition"].value as? String, "ab")
        app.buttons["delete"].tap()
        XCTAssertEqual(app.buttons["composition"].value as? String, "a")
        app.buttons["space"].tap()
        assertOutput("甲", in: app)
    }

    func testInvalidCompositionBlocksReturnSymbolsAndModeSwitch() {
        let app = launchPractice()
        type("z", in: app)
        app.buttons["return"].tap()
        app.buttons["globe"].tap()
        XCTAssertEqual(app.buttons["globe"].value as? String, "中文")
        app.buttons["symbols"].tap()
        app.buttons["key-/"].tap()
        XCTAssertEqual(app.buttons["composition"].value as? String, "z")
        assertOutput("", in: app)
        app.buttons["symbols"].tap()
        app.buttons["delete"].tap()
        type("a", in: app)
        app.buttons["space"].tap()
        assertOutput("甲", in: app)
    }

    func testValidCompositionCommitsOnModeSwitch() {
        let app = launchPractice()
        type("ab", in: app)
        app.buttons["globe"].tap()
        assertOutput("測試", in: app)
        XCTAssertEqual(app.buttons["globe"].value as? String, "英文")
        type("ab", in: app)
        assertOutput("測試Ab", in: app)
    }

    func testSymbolCommitAndPageResetPreserveComposition() {
        let app = launchPractice()
        type("a", in: app)
        app.buttons["symbols"].tap()
        XCTAssertEqual(app.buttons["composition"].value as? String, "a")
        app.buttons["key-/"].tap()
        assertOutput("甲/", in: app)
        app.buttons["more-symbols"].tap()
        app.buttons["key-+"].tap()
        app.buttons["symbols"].tap()
        app.buttons["symbols"].tap()
        XCTAssertTrue(app.buttons["key-/"].isHittable)
        app.buttons["key-，"].tap()
        assertOutput("甲/+，", in: app)
    }

    func testLongPressCommaCompositionAndRawCommit() {
        let app = launchPractice()
        app.buttons["key-2"].press(forDuration: 0.7)
        app.buttons["key-2"].press(forDuration: 0.7)
        XCTAssertEqual(app.buttons["composition"].value as? String, ",,")
        app.buttons["space"].tap()
        assertOutput("，", in: app)
        type("ab", in: app)
        app.buttons["composition"].press(forDuration: 0.7)
        assertOutput("，ab", in: app)
        XCTAssertFalse(app.buttons["composition"].isHittable)
    }

    func testHeldDeleteStopsAfterRelease() {
        let app = launchPractice()
        app.buttons["globe"].tap()
        type("abcdefgh", in: app)
        app.buttons["delete"].press(forDuration: 1.4)
        assertOutput("", in: app)
        type("a", in: app)
        app.buttons["space"].tap()
        assertOutput("a ", in: app)
    }

    func testHomophoneSeedBlocksLiteralAndModeSwitchAndCanCancel() {
        let app = launchPractice(["--reset-ui-testing"])
        app.buttons["key-9"].press(forDuration: 0.7)
        type("mnfo", in: app)
        app.buttons["return"].tap()
        app.buttons["globe"].tap()
        XCTAssertEqual(app.buttons["globe"].value as? String, "中文")
        XCTAssertEqual(app.buttons["composition"].value as? String, "'mnfo")
        assertOutput("", in: app)
        for _ in 0..<5 { app.buttons["delete"].tap() }
        XCTAssertFalse(app.buttons["composition"].isHittable)
        type("hx", in: app)
        app.buttons["space"].tap()
        assertOutput("愛", in: app)
    }

    func testHomophoneResolvedCandidatesRejectTypingAndReturnToSeed() {
        let app = launchPractice(["--reset-ui-testing"])
        app.buttons["key-9"].press(forDuration: 0.7)
        type("mnfo", in: app)
        app.buttons["candidate-0"].tap()
        XCTAssertEqual(app.buttons["composition"].value as? String, "'瞎")
        type("a", in: app)
        XCTAssertEqual(app.buttons["composition"].value as? String, "'瞎")
        app.buttons["delete"].tap()
        XCTAssertEqual(app.buttons["composition"].value as? String, "'mnfo")
        assertOutput("", in: app)
    }

    func testCompositionAndOutputSurviveRotation() {
        let app = launchPractice()
        type("a", in: app)
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(app.buttons["composition"].value as? String, "a")
        app.buttons["candidate-1"].tap()
        XCUIDevice.shared.orientation = .portrait
        expectation(for: NSPredicate { _, _ in app.frame.width < app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        assertOutput("乙", in: app)
    }

    func testLeavingPracticeAndRelaunchClearTransientInput() {
        let app = launchPractice()
        type("a", in: app)
        app.buttons["space"].tap()
        type("a", in: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(app.buttons["open-practice"], in: app)
        app.buttons["open-practice"].tap()
        assertOutput("", in: app)
        XCTAssertFalse(app.buttons["composition"].isHittable)
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["Fcitx5 嘸蝦米字表"].exists)
        reveal(app.buttons["open-practice"], in: app)
        app.buttons["open-practice"].tap()
        assertOutput("", in: app)
    }

}

extension KeyboardUITests {
    func testSetupInstructionsAndAppSettingsNavigation() {
        let app = launchHome(["--reset-ui-testing"])
        XCTAssertTrue(app.staticTexts["啟用鍵盤"].exists)
        let settingsLink = app.buttons["開啟 App 設定"]
        reveal(settingsLink, in: app)
        settingsLink.tap()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 5))
        app.activate()
        XCTAssertTrue(app.staticTexts["Fcitx5 嘸蝦米字表"].exists)
    }
}

extension KeyboardUITests {
    func testBundledDictionaryNeedsNoImportAndSurvivesRelaunch() {
        let app = launchHome([])
        for _ in 0..<2 {
            XCTAssertTrue(app.staticTexts["Fcitx5 嘸蝦米字表"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["table-count"].label, "30,916 組字碼 · 39,694 個候選項目")
            XCTAssertTrue(app.staticTexts["bundled-table-updates"].exists)
            XCTAssertFalse(app.buttons["import-table"].exists)
            XCTAssertFalse(app.buttons["remove-table"].exists)
            app.terminate()
            app.launchArguments = []
            app.launch()
        }
        reveal(app.buttons["open-practice"], in: app)
        app.buttons["open-practice"].tap()
        type("hx", in: app)
        app.buttons["space"].tap()
        assertOutput("愛", in: app)
    }
}
