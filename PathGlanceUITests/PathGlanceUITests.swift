import XCTest

/// Drives the real app against PATH's live data, so these need a network connection.
/// They check that the screens open and respond, not what the trains are.
/// Set `TEST_RUNNER_SHOT_DIR` to a folder to keep a screenshot of each step.
final class PathGlanceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(tab: String = "trains", extra: [String] = []) {
        // The welcome note has a test of its own; everywhere else it would be in the way.
        app.launchArguments = ["-startTab", tab, "-skipWelcome", "YES"] + extra
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

    private var picker: XCUIElement { app.otherElements["destinationPicker"] }

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
    private func revealBelowPreview(_ element: XCUIElement, preview name: String = "lockScreenPreview") {
        let preview = app.descendants(matching: .any)[name].firstMatch
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

    /// At rest the station is the title with the date under it. Scrolled on, the title
    /// leaves and the date stays; back at now, the title returns. The same at large text.
    func testHeaderGivesWayToTheDateWhenScrolled() {
        for (name, extra) in [("09-header", []), ("10-header-large", ["-textSizeOffset", "<integer>\(largestTextOffset)</integer>"])] {
            launch(extra: extra)
            XCTAssertTrue(picker.waitForExistence(timeout: 30))
            let title = app.buttons["originMenu"].firstMatch
            let date = app.buttons["dayBar"].firstMatch
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Departs'")).firstMatch.waitForExistence(timeout: 10))
            XCTAssertTrue(title.exists, "The station title shows at rest")
            XCTAssertTrue(date.exists && date.label.hasPrefix("Today"), "The date shows at rest")
            XCTAssertLessThan(title.frame.maxY, date.frame.maxY, "The date sits under the title")
            shot("\(name)-rest")

            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -260)))
            _ = title.waitForNonExistence(timeout: 5)
            shot("\(name)-scrolled")
            XCTAssertTrue(title.waitForNonExistence(timeout: 5), "Scrolled on, the station title leaves")
            XCTAssertTrue(date.exists && date.isHittable, "The date is always there")
            XCTAssertEqual(picker.buttons.count, 3, "The tabs stay")
            shot("\(name)-scrolled")

            // Back up past the next train: the title returns.
            from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: 420)))
            XCTAssertTrue(title.waitForExistence(timeout: 5), "Back at now or earlier, the station title returns")
            XCTAssertTrue(date.exists)
            app.terminate()
        }
    }

    /// The top of Settings > Text size: as far above the phone's own size as the slider goes.
    private let largestTextOffset = 3

    func testFavoriteStopAddsAColumn() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        // A favorite stop is starred in the station list, which stays open for it.
        app.buttons["originMenu"].firstMatch.tap()
        let star = app.buttons["star-newport"]
        XCTAssertTrue(star.waitForExistence(timeout: 5))
        reveal(star)
        if !star.isSelected { star.tap() }
        XCTAssertTrue(star.waitForSelected(), "The star fills in")
        XCTAssertTrue(app.buttons["station-newport"].exists, "Starring a stop leaves the list open")
        XCTAssertTrue(app.buttons["menuClearFavorites"].waitForExistence(timeout: 3), "With a favorite, the list offers to clear them")
        shot("02-station-stars")
        // Picking the station already in use closes the list and changes nothing else.
        let current = app.buttons["station-journalSquare"]
        for _ in 0..<4 where !current.isHittable { app.swipeDown() }
        current.tap()
        confirmGuideIfShown()
        let column = app.buttons["column-newport"]
        XCTAssertTrue(column.waitForExistence(timeout: 5), "Journal Square to 33rd passes Newport, so it gets a column")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Departs'")).firstMatch.waitForExistence(timeout: 10), "The list comes back with the new column")
        shot("03-columns")

        // Tapping a column's name hides it; it waits above the names until tapped again.
        column.tap()
        let hidden = app.buttons["showColumn-newport"]
        XCTAssertTrue(hidden.waitForExistence(timeout: 5), "A hidden column stays in reach")
        XCTAssertTrue(column.waitForNonExistence(timeout: 5))
        shot("03b-column-hidden")

        // Two columns are the least there can be: the last one beside your station stays.
        let destination = app.buttons["column-thirtyThirdStreet"]
        XCTAssertTrue(destination.exists)
        destination.tap()
        XCTAssertFalse(app.buttons["showColumn-thirtyThirdStreet"].waitForExistence(timeout: 2), "The second column cannot be hidden")
        XCTAssertTrue(destination.exists)

        hidden.tap()
        XCTAssertTrue(column.waitForExistence(timeout: 5), "Tapping it brings the column back")
    }

    func testIssueBannersPageOpenAndDismiss() {
        // Two made-up issues, and nothing put away from an earlier run.
        launch(extra: ["-sampleBanners", "YES", "-dismissedBanners", "<dict></dict>"])
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        let banner = app.buttons["issueBanner"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "An issue on this line shows above the trains")
        let dots = app.descendants(matching: .any)["issueBannerDots"].firstMatch
        XCTAssertTrue(dots.exists, "More than one notice: the dots say so")
        XCTAssertTrue(dots.label.hasPrefix("Notice 1 of"), "label is \(dots.label)")
        shot("21-banner")

        // Sideways for the next one, and back.
        // Fixed points on the screen: the first banner itself moves away with the swipe.
        let frame = banner.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let right = origin.withOffset(CGVector(dx: frame.minX + frame.width * 0.8, dy: frame.midY))
        let left = origin.withOffset(CGVector(dx: frame.minX + frame.width * 0.1, dy: frame.midY))
        right.press(forDuration: 0.05, thenDragTo: left, withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertTrue(dots.waitForLabel(prefix: "Notice 2 of"), "label is \(dots.label)")
        shot("22-banner-second")
        left.press(forDuration: 0.05, thenDragTo: right, withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertTrue(dots.waitForLabel(prefix: "Notice 1 of"), "label is \(dots.label)")

        // A tap opens the issue with its updates on a rail.
        app.buttons["issueBanner"].firstMatch.tap()
        XCTAssertTrue(app.buttons["muteRow"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["muteButton"].exists, "Muting is the row at the bottom, not a bell beside the X")
        shot("23-issue-detail")
        app.buttons["Close"].firstMatch.tap()
        _ = app.buttons["muteRow"].waitForNonExistence(timeout: 3)

        // The X puts one away for the day.
        let before = app.buttons.matching(identifier: "issueBannerDismiss").count
        app.buttons["issueBannerDismiss"].firstMatch.tap()
        let fewer = NSPredicate { _, _ in self.app.buttons.matching(identifier: "issueBannerDismiss").count == before - 1 }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: fewer, object: nil)], timeout: 5), .completed)
        shot("24-banner-dismissed")

        // The stops sheet carries the same notices.
        let trains = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Departs'"))
        XCTAssertTrue(trains.firstMatch.waitForExistence(timeout: 10))
        let onScreen = trains.allElementsBoundByIndex.filter { $0.frame.minY > 400 && $0.frame.maxY < 700 }.filter(\.isHittable)
        XCTAssertFalse(onScreen.isEmpty)
        onScreen[0].tap()
        XCTAssertTrue(app.buttons["laterTrain"].waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.buttons.matching(identifier: "issueBanner").count, 0)
        shot("25-stops-banner")
        app.buttons["Close"].firstMatch.tap()
    }

    func testTrainOpensItsStopsAndStepsToTheNext() {
        launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        let trains = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Departs'"))
        XCTAssertTrue(trains.firstMatch.waitForExistence(timeout: 10))
        // Rows above and below the screen exist too; take one that can be tapped.
        let onScreen = trains.allElementsBoundByIndex.filter { $0.frame.minY > 300 && $0.frame.maxY < 700 }.filter(\.isHittable)
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

    func testStationButtonBringsTheTrainsTabForward() {
        launch(tab: "issues")
        let button = app.buttons["stationButton"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["tab-issues"].isSelected, "The Issues tab should be the one showing")
        button.tap()
        XCTAssertTrue(app.buttons["station-hoboken"].waitForExistence(timeout: 5), "The station list should open")
        XCTAssertTrue(app.buttons["tab-trains"].isSelected, "The Trains tab should be behind the list")
        shot("20-station-from-issues")
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
        let picker = app.descendants(matching: .any)["shapePicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        let save = app.buttons["saveLook"]
        func preset(_ id: String) -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: "preset-\(id)").firstMatch
        }
        XCTAssertTrue(preset("default").waitForExistence(timeout: 10))
        let carousel = app.descendants(matching: .any)["lockScreenPreview"].firstMatch
        let restore = app.buttons["restorePreset"]
        // An earlier run that failed may have left another preset saved, or Default edited.
        func backToDefault() {
            for _ in 0..<12 where !preset("default").isSelected { carousel.swipeRight() }
            expectSelected(preset("default"))
            revealBelowPreview(restore)
            if restore.isEnabled { restore.tap() }
            if save.waitForExistence(timeout: 2) { save.tap() }
            XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        }
        backToDefault()
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "preset-custom").firstMatch.exists, "There is no Custom card")
        shot("09-widget-tab")

        // Tapping a neighbour in the carousel chooses it and offers Save; Cancel puts it back.
        preset("packed").tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Choosing another preset should offer Save")
        XCTAssertTrue(preset("large").waitForExistence(timeout: 5))
        preset("large").tap()
        expectSelected(preset("large"))
        shot("10-presets")
        app.buttons["cancelLook"].tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5), "Cancel should revert to the saved look")
        expectSelected(preset("default"))

        // A swipe on the carousel moves one preset on, and Save sends it to the widget.
        carousel.swipeLeft()
        expectSelected(preset("packed"))
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))

        // An edit stays with the preset in hand, which says so once it differs.
        XCTAssertFalse(preset("packed").label.contains("edited"))
        let serif = app.buttons["font-serif"]
        revealBelowPreview(serif)
        serif.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        expectSelected(preset("packed"))
        XCTAssertTrue(preset("packed").label.contains("edited"), "label is \(preset("packed").label)")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        shot("11-edited-preset")

        // The edit waits with its preset while another is looked at.
        carousel.swipeRight()
        expectSelected(preset("default"))
        XCTAssertTrue(preset("packed").label.contains("edited"))
        app.buttons["cancelLook"].tap()
        expectSelected(preset("packed"))

        // Restore preset undoes it, on Save like any other change.
        revealBelowPreview(restore)
        XCTAssertTrue(restore.isEnabled)
        restore.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(preset("packed").label.contains("edited"))
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        XCTAssertFalse(restore.isEnabled, "Nothing left to restore")

        // The Round tab has its own presets and keeps its own edits.
        picker.buttons["Round widget"].tap()
        XCTAssertTrue(preset("round-minutes").waitForExistence(timeout: 5))
        shot("12-round-tab")
        XCTAssertFalse(app.buttons["roundShowsPeriod"].exists, "Minutes have no AM or PM to show")
        preset("round-clock").tap()
        expectSelected(preset("round-clock"))
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["roundShowsPeriod"].waitForExistence(timeout: 5), "A clock time can show AM or PM")
        shot("13-round-clock")
        let roundSerif = app.buttons["roundFont-serif"]
        revealBelowPreview(roundSerif, preview: "roundPreview")
        roundSerif.tap()
        expectSelected(preset("round-clock"))
        XCTAssertTrue(preset("round-clock").label.contains("edited"))
        shot("14-round-edited")
        app.buttons["cancelLook"].tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        expectSelected(preset("round-minutes"))

        // A swipe under the carousel goes back to the rectangle.
        let low = app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.7))
        low.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.7)))
        XCTAssertTrue(picker.buttons["Rectangle widget"].waitForExistence(timeout: 5))
        let rectangle = picker.buttons["Rectangle widget"]
        let selected = NSPredicate(format: "isSelected == true")
        wait(for: [XCTNSPredicateExpectation(predicate: selected, object: rectangle)], timeout: 5)

        // Back to the default for later runs.
        backToDefault()
    }

    /// The legend closes for good and comes back from Settings; hiding the station row
    /// is explained first; the Show options change the preview.
    func testLegendAndShowOptions() {
        // The legend showing and no guide silenced, whatever an earlier run left.
        launch(tab: "widget", extra: ["-widgetLegendHidden", "NO", "-silencedGuides", "()"])
        let legend = app.descendants(matching: .any)["widgetLegend"].firstMatch
        XCTAssertTrue(legend.waitForExistence(timeout: 30), "The legend sits under the preview")
        let dots = app.descendants(matching: .any)["widgetLegendDots"].firstMatch
        XCTAssertTrue(dots.label.hasPrefix("Mark 1 of"), "label is \(dots.label)")
        shot("15-legend")
        app.buttons["widgetLegendDismiss"].firstMatch.tap()
        XCTAssertTrue(legend.waitForNonExistence(timeout: 5), "The X closes the legend")

        // Settings, About, Widget legend brings it back and steps out of the way.
        app.buttons["settingsButton"].tap()
        let row = app.buttons["widgetLegendRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        reveal(row)
        for _ in 0..<3 where row.frame.maxY > app.buttons["tab-trains"].frame.minY - 8 { app.swipeUp() }
        row.tap()
        XCTAssertTrue(app.buttons["Close"].waitForNonExistence(timeout: 5), "Settings closes")
        XCTAssertTrue(legend.waitForExistence(timeout: 5), "The legend is back")

        // Hiding the station row is explained before it happens.
        let refresh = app.buttons["previewRefresh"].firstMatch
        XCTAssertTrue(refresh.waitForExistence(timeout: 10), "The station row is the preview's top row")
        let header = app.buttons["showsHeader"]
        revealBelowPreview(header)
        XCTAssertTrue(header.isSelected)
        shot("16-show-section")
        header.tap()
        XCTAssertTrue(app.buttons["guideDontShowAgain"].waitForExistence(timeout: 5), "Hiding the station row is explained first")
        shot("17-hide-header-guide")
        app.buttons["guideConfirm"].tap()
        XCTAssertTrue(app.buttons["guideConfirm"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(header.isSelected)
        XCTAssertTrue(refresh.waitForNonExistence(timeout: 5), "The row is gone from the preview")

        // The rest are plain ticks.
        for option in ["skipNext", "showsPeriod", "compress"] {
            let box = app.buttons[option]
            revealBelowPreview(box)
            XCTAssertFalse(box.isSelected, "\(option) starts off")
            box.tap()
            XCTAssertTrue(box.isSelected)
        }
        shot("18-show-options-on")
        XCTAssertTrue(app.buttons["saveLook"].exists)
        app.buttons["cancelLook"].tap()
        XCTAssertTrue(app.buttons["saveLook"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(header.isSelected, "Cancel brings the station row back")
    }

    /// A guide raised from inside Settings and closed must leave Settings working.
    func testSettingsOpensAgainAfterAGuide() {
        launch(tab: "widget")
        let menu = app.buttons["settingsButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        menu.tap()
        let fold = app.buttons["fold-settings-preferences"]
        XCTAssertTrue(fold.waitForExistence(timeout: 5))
        app.swipeUp()
        let restore = app.buttons["restoreDefaults"]
        reveal(restore)
        for _ in 0..<3 where restore.frame.maxY > app.buttons["tab-trains"].frame.minY - 8 { app.swipeUp() }
        restore.tap()
        XCTAssertTrue(app.buttons["guideCancel"].waitForExistence(timeout: 5))
        app.buttons["guideCancel"].tap()
        XCTAssertTrue(app.buttons["guideCancel"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(restore.exists, "Settings is still there under the guide")

        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(fold.waitForNonExistence(timeout: 5), "The X closes Settings")
        menu.tap()
        XCTAssertLessThan(menu.frame.width, 100, "The button keeps its own frame, for VoiceOver and for this tap")
        XCTAssertTrue(fold.waitForExistence(timeout: 5), "Settings opens again")
    }

    /// Waits for a carousel card to become the chosen one.
    private func expectSelected(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let selected = NSPredicate(format: "isSelected == true")
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: selected, object: element)], timeout: 6)
        XCTAssertEqual(result, .completed, "\(element) should be the chosen preset", file: file, line: line)
    }

    func testSettingsSheetDragsUpAndDownAndRestoresDefaults() {
        launch(tab: "widget")
        let menu = app.buttons["settingsButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        menu.tap()
        let station = app.buttons["fold-settings-preferences"]
        XCTAssertTrue(station.waitForExistence(timeout: 5))
        shot("12-settings-sheet")

        // At half height a drag on the content pulls the sheet up to full height.
        let top = station.frame.minY
        app.swipeUp()
        XCTAssertLessThan(station.frame.minY, top - 100, "Dragging the content up should expand the sheet")

        let restore = app.buttons["restoreDefaults"]
        reveal(restore)
        // The last row can come to rest behind the tab bar, where it still counts as hittable.
        for _ in 0..<3 where restore.frame.maxY > app.buttons["tab-trains"].frame.minY - 8 { app.swipeUp() }
        restore.tap()
        XCTAssertTrue(app.buttons["guideConfirm"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["guideDontShowAgain"].exists, "A destructive action always asks")
        // Three things can be kept, and none is ticked to begin with.
        for kept in ["favoriteStops", "mutedIssues", "presets"] {
            let box = app.buttons["guideOption-\(kept)"]
            XCTAssertTrue(box.exists, "\(kept) can be kept")
            XCTAssertFalse(box.isSelected, "\(kept) starts unticked")
        }
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
        XCTAssertTrue(app.buttons["fold-settings-preferences"].waitForExistence(timeout: 5))

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

    func testWelcomeShowsUntilSilenced() {
        // An empty list on the command line stands in for a fresh install's.
        app.launchArguments = ["-silencedGuides", "()"]
        app.launch()
        let gotIt = app.buttons["guideConfirm"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["guideCancel"].exists)
        XCTAssertEqual(gotIt.label, "Got it")
        // One button spans the popup: far wider than its title needs.
        XCTAssertGreaterThan(gotIt.frame.width, app.windows.firstMatch.frame.width * 0.6)
        shot("19-welcome")
        app.buttons["guideDontShowAgain"].tap()
        gotIt.tap()
        XCTAssertTrue(gotIt.waitForNonExistence(timeout: 5))

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["tab-trains"].waitForExistence(timeout: 30))
        XCTAssertFalse(gotIt.waitForExistence(timeout: 3))

        // Still there to read under Settings, About.
        app.buttons["tab-widget"].tap()
        app.buttons["settingsButton"].tap()
        let note = app.buttons["welcomeNote"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        reveal(note)
        note.tap()
        XCTAssertTrue(gotIt.waitForExistence(timeout: 5))
        gotIt.tap()
    }

    /// Lines preferred lives in Settings: it starts folded, a line can be dragged first,
    /// the Trains tabs follow, and hiding one is explained before it happens.
    func testLinesPreferredReordersTheTabsAndExplainsHiding() {
        let menu = app.buttons["settingsButton"]
        let fold = app.buttons["fold-settings-lines"]
        let wtc = app.descendants(matching: .any)["lineHandle-worldTradeCenter"].firstMatch
        let first = app.descendants(matching: .any)["lineHandle-thirtyThirdStreet"].firstMatch

        /// Opens Settings with Lines preferred unfolded and its rows in the clear.
        func openLines(expectFolded: Bool) {
            XCTAssertTrue(menu.waitForExistence(timeout: 30))
            menu.tap()
            XCTAssertTrue(fold.waitForExistence(timeout: 5))
            if expectFolded { XCTAssertFalse(wtc.exists, "Lines preferred starts folded") }
            if !wtc.exists { fold.tap() }
            XCTAssertTrue(wtc.waitForExistence(timeout: 5))
            // Pull the sheet up to full height, then bring both rows into the clear between
            // the sheet's title and the tab bar: a row behind either cannot be dragged.
            app.swipeUp()
            let title = app.staticTexts["Settings"].firstMatch
            let tabBarTop = app.buttons["tab-trains"].frame.minY
            let middle = (title.frame.maxY + tabBarTop) / 2
            for _ in 0..<10 {
                let top = min(first.frame.minY, wtc.frame.minY), bottom = max(first.frame.maxY, wtc.frame.maxY)
                if top > title.frame.maxY + 30 && bottom < tabBarTop - 30 { break }
                let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 200, dy: middle))
                let distance = max(-200, min(200, middle - (top + bottom) / 2))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
            }
        }

        launch(tab: "widget", extra: ["-foldedSections", "(settings-lines)"])
        openLines(expectFolded: true)
        // World Trade Center above 33rd Street: its handle is dragged onto the first row's.
        if wtc.frame.minY > first.frame.minY { wtc.press(forDuration: 0.1, thenDragTo: first) }
        // Let the row settle before looking.
        _ = app.buttons["no-such-button"].waitForExistence(timeout: 1)
        shot("26-lines-reordered")
        XCTAssertLessThan(wtc.frame.minY, first.frame.minY, "The dragged line is now first")

        // The Trains tabs lead with the line put first, and the list under them is its list.
        app.buttons["Close"].firstMatch.tap()
        app.buttons["tab-trains"].tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        let tabs = picker.buttons.allElementsBoundByIndex
        XCTAssertTrue(tabs.first?.label.contains("World Trade Center") ?? false, "First tab is \(tabs.first?.label ?? "none")")
        XCTAssertTrue(app.buttons["column-worldTradeCenter"].waitForExistence(timeout: 10), "The page follows the tab that leads")
        shot("27-tabs-reordered")

        // Back to the standard order for later runs, and it is remembered across a launch.
        app.terminate()
        launch(tab: "widget")
        openLines(expectFolded: false)
        XCTAssertLessThan(wtc.frame.minY, first.frame.minY, "The order is remembered")
        first.press(forDuration: 0.1, thenDragTo: wtc)
        XCTAssertLessThan(first.frame.minY, wtc.frame.minY, "33rd Street leads again")

        // Hiding a line is explained first.
        let newark = app.buttons["line-newark"].firstMatch
        if !newark.isSelected { newark.tap() }
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
        let mute = app.buttons["muteRow"]
        XCTAssertTrue(mute.waitForExistence(timeout: 5))
        reveal(mute)
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

    func waitForLabel(prefix: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@", prefix), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func waitForLabelChange(from old: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", old), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
