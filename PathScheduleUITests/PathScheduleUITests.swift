import XCTest

/// Drives the real app against PATH's live data, so these need a network connection.
/// They check that the screens open and respond, not what the trains are.
/// Set `TEST_RUNNER_SHOT_DIR` to a folder to keep a screenshot of each step.
final class PathScheduleUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(tab: String = "trains") {
        app.launchArguments = ["-startTab", tab]
        app.launch()
    }

    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let folder = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
        }
    }

    private var picker: XCUIElement { app.segmentedControls["destinationPicker"] }

    func testTrainsTabSwitchesDestinationByTapAndSwipe() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30), "The timetable should download and the destination tabs appear")
        shot("01-trains")

        let second = picker.buttons.element(boundBy: 1)
        second.tap()
        XCTAssertTrue(second.isSelected)
        shot("02-second-destination")

        // A sideways swipe on the list turns to the next destination.
        let right = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.7))
        let left = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.7))
        right.press(forDuration: 0.05, thenDragTo: left, withVelocity: .fast, thenHoldForDuration: 0)
        shot("03-after-swipe")
        XCTAssertTrue(picker.buttons.element(boundBy: 2).waitForSelected(), "Swiping left should select the third destination")
        left.press(forDuration: 0.05, thenDragTo: right, withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertTrue(second.waitForSelected())
    }

    func testFavoriteStopAddsAColumn() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        // Favorite stops are edited from the station menu.
        app.buttons["originMenu"].firstMatch.tap()
        app.buttons["Favorite stops"].firstMatch.tap()
        let newport = app.buttons["favorite-newport"]
        XCTAssertTrue(newport.waitForExistence(timeout: 5))
        if !newport.isSelected { newport.tap() }
        let christopher = app.buttons["favorite-christopherStreet"]
        if !christopher.isSelected { christopher.tap() }
        shot("04-favorites-sheet")
        XCTAssertTrue(app.buttons["tab-issues"].exists, "The tab bar stays in view over a sheet")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Newport"].waitForExistence(timeout: 5), "Journal Square to 33rd passes Newport, so it gets a column")
        shot("05-columns")
    }

    func testTrainOpensItsStops() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        let trains = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Departs'"))
        XCTAssertTrue(trains.firstMatch.waitForExistence(timeout: 10))
        // Rows above and below the screen exist too; take one that can be tapped, clear of the pinned header.
        let onScreen = trains.allElementsBoundByIndex.filter { $0.isHittable && $0.frame.minY > 380 && $0.frame.maxY < 760 }
        XCTAssertFalse(onScreen.isEmpty)
        onScreen[0].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        shot("06-stops-sheet")
        // The arrows step to the next train without closing the sheet.
        let titleBefore = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ' to '")).firstMatch.label
        app.buttons["laterTrain"].tap()
        let titleAfter = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ' to '")).firstMatch.label
        XCTAssertNotEqual(titleBefore, titleAfter)
        XCTAssertTrue(app.buttons["Close"].exists)
        app.buttons["Close"].tap()
    }

    func testDateJumpAndBackToNow() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        let dayBar = app.buttons["dayBar"].firstMatch
        XCTAssertTrue(dayBar.waitForExistence(timeout: 10))
        dayBar.tap()
        shot("07-date-popup")
        XCTAssertTrue(app.buttons["Back to now"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()

        // Scroll a long way down; the way back appears.
        for _ in 0..<6 { app.swipeUp(velocity: .fast) }
        let back = app.buttons["backToNow"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Scrolling hours ahead should offer a way back to now")
        shot("08-scrolled-away")
        back.tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 5))
    }

    func testLockScreenOptionsOpenFromPreview() {
        launch(tab: "settings")
        let preview = app.buttons["lockScreenPreview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 30))
        preview.tap()
        let serif = app.buttons["font-serif"]
        XCTAssertTrue(serif.waitForExistence(timeout: 5))
        serif.tap()
        XCTAssertTrue(serif.isSelected)
        shot("09-lock-screen-options")
        app.buttons["font-standard"].tap()
        app.buttons["Close"].tap()
    }

    func testStationButtonChangesTheStation() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        app.buttons["stationButton"].firstMatch.tap()
        app.buttons["Hoboken"].firstMatch.tap()
        XCTAssertTrue(app.buttons["From Hoboken. Change station"].firstMatch.waitForExistence(timeout: 5))
        shot("13-hoboken")
        // Put it back so later runs start from the default.
        app.buttons["stationButton"].firstMatch.tap()
        app.buttons["Journal Square"].firstMatch.tap()
    }

    func testSettingsAndIssuesTabs() {
        launch(tab: "settings")
        let lines = app.buttons["settings-lines"]
        XCTAssertTrue(lines.waitForExistence(timeout: 10))
        lines.tap()
        XCTAssertTrue(app.buttons["line-newark"].waitForExistence(timeout: 5))
        shot("10-lines-sheet")
        app.buttons["Close"].tap()

        app.buttons["tab-issues"].tap()
        sleep(1)
        shot("11-issues")
        XCTAssertTrue(app.staticTexts["Issues"].waitForExistence(timeout: 5))
    }

    func testLandscapeKeepsTheList() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        shot("12-landscape")
        XCUIDevice.shared.orientation = .portrait
    }
}

private extension XCUIElement {
    func waitForSelected(timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
