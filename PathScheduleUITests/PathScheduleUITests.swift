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

    /// Guides explain an action the first time. Accept one if it is showing.
    private func confirmGuideIfShown() {
        let confirm = app.buttons["guideConfirm"]
        if confirm.waitForExistence(timeout: 2) {
            confirm.tap()
            _ = confirm.waitForNonExistence(timeout: 3)
        }
    }

    /// Scrolls until `element` can be tapped.
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
    }

    /// On the Widget tab the options scroll under the pinned preview and the tab bar, and a
    /// row behind either still counts as hittable. Drag until it is in the clear between them.
    private func revealBelowPreview(_ element: XCUIElement) {
        let preview = app.descendants(matching: .any)["lockScreenPreview"].firstMatch
        let tabBarTop = app.buttons["tab-trains"].frame.minY
        let middle = (preview.frame.maxY + tabBarTop) / 2
        for _ in 0..<12 {
            let frame = element.frame
            if frame.minY > preview.frame.maxY + 8 && frame.maxY < tabBarTop - 8 { return }
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 60, dy: middle))
            let distance = max(-220, min(220, middle - frame.midY))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
        }
    }

    // MARK: Trains

    func testTrainsTabSwitchesDestinationByTapAndSwipe() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30), "The timetable should download and the destination tabs appear")
        shot("01-trains")

        let second = picker.buttons.element(boundBy: 1)
        second.tap()
        XCTAssertTrue(second.isSelected)

        // A sideways swipe on the list turns to the next destination.
        let right = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.7))
        let left = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.7))
        right.press(forDuration: 0.05, thenDragTo: left, withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertTrue(picker.buttons.element(boundBy: 2).waitForSelected(), "Swiping left should select the third destination")
        left.press(forDuration: 0.05, thenDragTo: right, withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertTrue(second.waitForSelected())
    }

    func testFavoriteStopAddsAColumn() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        // Favorite stops are edited from the station list.
        app.buttons["originMenu"].firstMatch.tap()
        let favorites = app.buttons["menuFavoriteStops"]
        XCTAssertTrue(favorites.waitForExistence(timeout: 5))
        reveal(favorites)
        favorites.tap()
        let newport = app.buttons["favorite-newport"]
        XCTAssertTrue(newport.waitForExistence(timeout: 5))
        if !newport.isSelected { newport.tap() }
        shot("02-favorites-sheet")
        XCTAssertTrue(app.buttons["tab-issues"].exists, "The tab bar stays in view over a sheet")
        // Dragging the content, not the title, brings the last row up clear of the tab bar.
        let last = app.buttons["favorite-thirtyThirdStreet"]
        let tabBarTop = app.buttons["tab-issues"].frame.minY
        for _ in 0..<4 where !(last.exists && last.frame.maxY <= tabBarTop) {
            newport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05, thenDragTo: newport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -5)))
        }
        XCTAssertTrue(last.exists && last.frame.maxY <= tabBarTop, "The sheet's content scrolls until its end is above the tab bar")
        shot("02b-favorites-scrolled")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Newport"].waitForExistence(timeout: 5), "Journal Square to 33rd passes Newport, so it gets a column")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Departs'")).firstMatch.waitForExistence(timeout: 10), "The list comes back with the new column")
        shot("03-columns")
    }

    func testTrainOpensItsStopsAndStepsToTheNext() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        let trains = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Departs'"))
        XCTAssertTrue(trains.firstMatch.waitForExistence(timeout: 10))
        // Rows above and below the screen exist too; take one that can be tapped.
        let onScreen = trains.allElementsBoundByIndex.filter { $0.isHittable && $0.frame.minY > 300 && $0.frame.maxY < 700 }
        XCTAssertFalse(onScreen.isEmpty)
        onScreen[0].tap()
        let time = app.descendants(matching: .any)["stopsTime"].firstMatch
        XCTAssertTrue(app.buttons["laterTrain"].waitForExistence(timeout: 5))
        shot("04-stops-sheet")
        // Pushing the content up shows the last stop whole, above the tab bar.
        let stopsStart = time.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        stopsStart.press(forDuration: 0.05, thenDragTo: stopsStart.withOffset(CGVector(dx: 0, dy: -250)))
        shot("04b-stops-scrolled")
        // The arrow turns to the next train without closing the sheet.
        let before = time.label
        app.buttons["laterTrain"].tap()
        XCTAssertTrue(time.waitForLabelChange(from: before), "The later-train arrow should show another time")
        XCTAssertTrue(app.buttons["Close"].exists)
        shot("05-next-train")
        app.buttons["Close"].tap()
    }

    func testDateJumpAndBackToNow() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        let dayBar = app.buttons["dayBar"].firstMatch
        XCTAssertTrue(dayBar.waitForExistence(timeout: 10))
        dayBar.tap()
        XCTAssertTrue(app.buttons["Back to now"].waitForExistence(timeout: 5))
        shot("06-date-popup")
        app.buttons["Close"].tap()

        // Scroll a long way down; the way back appears.
        for _ in 0..<6 { app.swipeUp(velocity: .fast) }
        let back = app.buttons["backToNow"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Scrolling hours ahead should offer a way back to now")
        back.tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 8))
    }

    func testStationButtonChangesTheStation() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        app.buttons["stationButton"].firstMatch.tap()
        let hoboken = app.buttons["station-hoboken"]
        XCTAssertTrue(hoboken.waitForExistence(timeout: 5))
        shot("07-station-popover")
        hoboken.tap()
        confirmGuideIfShown()
        XCTAssertTrue(app.buttons["From Hoboken. Change station"].firstMatch.waitForExistence(timeout: 5))
        // Put it back so later runs start from the default.
        app.buttons["stationButton"].firstMatch.tap()
        app.buttons["station-journalSquare"].tap()
        confirmGuideIfShown()
    }

    func testLandscapeKeepsTheList() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        shot("08-landscape")
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: Widget

    func testWidgetLookIsEditedThenSaved() {
        launch(tab: "widget")
        XCTAssertTrue(app.buttons["presetsRow"].waitForExistence(timeout: 30))
        shot("09-widget-tab")
        let save = app.buttons["saveLook"]

        // A preset changes the preview and offers Save; saving hides the button.
        app.buttons["presetsRow"].tap()
        let large = app.buttons["preset-large"]
        XCTAssertTrue(large.waitForExistence(timeout: 5))
        shot("10-presets")
        // A custom look left by an earlier run is listed first and pushes Large down.
        reveal(large)
        large.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Choosing another look should offer Save")
        // Cancel puts the look back and takes both buttons away.
        app.buttons["cancelLook"].tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5), "Cancel should revert to the saved look")
        app.buttons["presetsRow"].tap()
        XCTAssertTrue(large.waitForExistence(timeout: 5))
        reveal(large)
        large.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))

        // Editing it makes it a custom look, which Save keeps as the custom preset.
        let serif = app.buttons["font-condensed"]
        reveal(serif)
        serif.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        for _ in 0..<4 where !app.buttons["presetsRow"].isHittable { app.swipeDown() }
        app.buttons["presetsRow"].tap()
        let custom = app.buttons["preset-custom"]
        reveal(custom)
        XCTAssertTrue(custom.waitForExistence(timeout: 5), "A saved custom look should be listed")
        XCTAssertTrue(custom.isSelected)
        shot("11-custom-preset")

        // Back to the default for later runs.
        for _ in 0..<4 where !app.buttons["preset-default"].isHittable { app.swipeDown() }
        app.buttons["preset-default"].tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
    }

    func testSettingsSheetDragsUpAndDownAndRestoresDefaults() {
        launch(tab: "widget")
        let menu = app.buttons["settingsButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        menu.tap()
        let station = app.buttons["fold-settings-station"]
        XCTAssertTrue(station.waitForExistence(timeout: 5))
        shot("12-settings-sheet")

        // At half height a drag on the content pulls the sheet up to full height.
        let top = station.frame.minY
        app.swipeUp()
        XCTAssertLessThan(station.frame.minY, top - 100, "Dragging the content up should expand the sheet")

        let restore = app.buttons["restoreDefaults"]
        reveal(restore)
        restore.tap()
        XCTAssertTrue(app.buttons["guideConfirm"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["guideDontShowAgain"].exists, "A destructive action always asks")
        shot("13-restore-guide")
        app.buttons["guideConfirm"].tap()

        XCTAssertTrue(app.buttons["guideConfirm"].waitForNonExistence(timeout: 5))

        // Small pulls on the content scroll it back to its top without lowering the sheet.
        // (`isHittable` is true for a row scrolled out under the title, so go by where it is.)
        let title = app.staticTexts["Settings"].firstMatch
        func pull(_ distance: CGFloat, fast: Bool = false) {
            let start = title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 160))
            let end = start.withOffset(CGVector(dx: 0, dy: distance))
            if fast {
                start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
            } else {
                start.press(forDuration: 0.05, thenDragTo: end)
            }
        }
        for _ in 0..<20 where station.frame.minY < title.frame.maxY { pull(110) }
        XCTAssertGreaterThan(station.frame.minY, title.frame.maxY, "A pull down scrolls the content back to its top")
        // (The last of those may have carried the sheet down a step; the title takes it back up.)
        title.swipeUp(velocity: .fast)
        // From the top of the content, a pull down takes the sheet to half height...
        let full = title.frame.minY
        pull(300, fast: true)
        shot("13b-after-pull-down")
        XCTAssertGreaterThan(title.frame.minY, full + 100, "Pulling the content down from its top should lower the sheet")
        // ...and a quick, short pull on the title closes it. It must never go up.
        app.staticTexts["Settings"].firstMatch.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["Close"].waitForNonExistence(timeout: 5), "Pulling down at half height should close the sheet")
    }

    func testSettingsShowAboutAndSupport() {
        launch(tab: "widget")
        let menu = app.buttons["settingsButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        menu.tap()
        XCTAssertTrue(app.buttons["fold-settings-station"].waitForExistence(timeout: 5))

        let coffee = app.buttons["donate-coffee"]
        reveal(coffee)
        XCTAssertTrue(app.buttons["donate-cashapp"].exists)
        shot("17-support")

        let privacy = app.buttons["privacyPolicy"]
        reveal(privacy)
        XCTAssertTrue(app.buttons["emailDeveloper"].exists)
        XCTAssertTrue(app.buttons["reportProblem"].exists)
        XCTAssertTrue(app.buttons["shareApp"].exists)
        let version = app.descendants(matching: .any)["appVersion"].firstMatch
        reveal(version)
        // "1.0 (1)": the version, then the build in brackets.
        let text = [version.label, version.value as? String ?? ""].joined(separator: " ")
        XCTAssertNotNil(text.range(of: #"\d+\.\d+(\.\d+)? \(\d+\)"#, options: .regularExpression), "Got: \(text)")
        shot("18-about")
    }

    func testHidingALineIsExplainedFirst() {
        launch(tab: "widget")
        let newark = app.buttons["line-newark"]
        XCTAssertTrue(newark.waitForExistence(timeout: 30))
        revealBelowPreview(newark)
        if !newark.isSelected {
            newark.tap()
            revealBelowPreview(newark)
        }
        newark.tap()
        XCTAssertTrue(app.buttons["guideDontShowAgain"].waitForExistence(timeout: 5), "Hiding a line is explained before it happens")
        shot("14-hide-line-guide")
        app.buttons["guideCancel"].tap()
        XCTAssertTrue(newark.isSelected, "Cancel leaves the line showing")
    }

    // MARK: Issues

    func testMutingAnIssueKindAsksFirst() {
        launch(tab: "issues")
        // Planned-work and elevator notices are open most days; take whichever issue is first.
        let issue = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Since ' OR label CONTAINS ' – '")).firstMatch
        guard issue.waitForExistence(timeout: 20) else { return } // no issues at all today
        shot("15-issues")
        issue.tap()
        let mute = app.buttons["muteButton"]
        XCTAssertTrue(mute.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sortUpdates"].exists)
        if mute.label.hasPrefix("Unmute") {
            mute.tap()
            confirmGuideIfShown()
        }
        XCTAssertTrue(mute.label.hasPrefix("Mute"), "label is \(mute.label)")
        mute.tap()
        // Muting is explained before it happens.
        XCTAssertTrue(app.buttons["guideConfirm"].waitForExistence(timeout: 5), "label is \(mute.label)")
        shot("16-mute-guide")
        app.buttons["guideConfirm"].tap()
        _ = app.buttons["guideConfirm"].waitForNonExistence(timeout: 3)
        XCTAssertTrue(mute.label.hasPrefix("Unmute"))
        // Leave it as it was.
        mute.tap()
        confirmGuideIfShown()
        app.buttons["Close"].firstMatch.tap()
    }
}

private extension XCUIElement {
    func waitForSelected(timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func waitForLabelChange(from old: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", old), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
