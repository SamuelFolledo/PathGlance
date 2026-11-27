import Foundation
import Testing
@testable import PathGlance

@Suite("Round widget")
struct RoundWidgetTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func board(_ first: [Double], _ second: [Double] = [6, 16], delay: DelayLevel = .none) -> Board {
        func times(_ minutes: [Double]) -> [Date] { minutes.map { now.addingTimeInterval($0 * 60) } }
        return Board(station: .journalSquare, rows: [
            BoardRow(label: "33rd", target: .thirtyThirdStreet, delay: delay, times: times(first)),
            BoardRow(label: "WTC", target: .worldTradeCenter, times: times(second)),
        ])
    }

    private func face(_ content: RoundContent, _ board: Board, line: Station? = nil) -> RoundFace? {
        RoundFace.make(board: board, content: content, line: line, now: now)
    }

    @Test func fivePresetsEachWithItsOwnContentAndFont() {
        #expect(RoundPreset.builtIn.map(\.id) == ["minutes", "clock", "ring", "nexttwo", "twolines"])
        #expect(Set(RoundPreset.builtIn.map(\.look.content)) == Set(RoundContent.allCases))
        let fonts = Dictionary(uniqueKeysWithValues: RoundPreset.builtIn.map { ($0.look.content, $0.look.font) })
        #expect(fonts == [.minutes: .standard, .clock: .standard, .ring: .standard, .nextTwo: .rounded, .twoLines: .condensed])
        #expect(RoundPreset.matching(RoundLook()) == RoundPreset.builtIn[0])
        #expect(RoundPreset.matching(RoundLook(content: .minutes, font: .serif)) == nil)
    }

    @Test func minutesShowsTheLineAndTheWait() {
        let face = face(.minutes, board([4.5, 14]))
        #expect(face?.label == "33rd")
        #expect(face?.value == "4")
        #expect(face?.unit == "min")
        #expect(face?.spokenText == "33rd, 4 min")
    }

    @Test func underAMinuteIsNowAndAnHourAwayIsAClockTime() {
        let soon = face(.minutes, board([0.5, 9]))
        #expect(soon?.value == "Now")
        #expect(soon?.unit == "")
        let far = face(.minutes, board([75]))
        #expect(far?.value == CompactTimes.clock(now.addingTimeInterval(75 * 60)))
        #expect(far?.unit == "")
    }

    @Test func clockShowsWhenTheTrainLeaves() {
        let face = face(.clock, board([4, 14]))
        #expect(face?.value == CompactTimes.clock(now.addingTimeInterval(4 * 60)))
        #expect(face?.unit == "")
    }

    @Test func ringFillsWithTheWaitAndIsFullAtTwentyMinutes() {
        #expect(face(.ring, board([5]))?.fraction == 0.25)
        #expect(face(.ring, board([40]))?.fraction == 1)
        #expect(face(.ring, board([0.2]))?.fraction == 0)
        #expect(face(.ring, board([5]))?.value == "5")
    }

    @Test func nextTwoListsBothWaits() {
        #expect(face(.nextTwo, board([4, 14]))?.value == "4, 14")
        #expect(face(.nextTwo, board([4]))?.value == "4")
        // The second is dropped once it is not a count of minutes.
        #expect(face(.nextTwo, board([4, 90]))?.value == "4")
    }

    @Test func twoLinesPairsEachLineWithItsWait() {
        let face = face(.twoLines, board([4, 14]))
        #expect(face?.pairs == [RoundFace.Pair(label: "33rd", value: "4"), RoundFace.Pair(label: "WTC", value: "6")])
        // The followed line comes first.
        let other = self.face(.twoLines, board([4, 14]), line: .worldTradeCenter)
        #expect(other?.pairs.map(\.label) == ["WTC", "33rd"])
    }

    @Test func followsTheChosenLineOrTheFirstWhenTheStationLacksIt() {
        #expect(face(.minutes, board([4]), line: .worldTradeCenter)?.label == "WTC")
        #expect(face(.minutes, board([4]), line: .newark)?.label == "33rd")
        #expect(face(.minutes, board([4]), line: nil)?.label == "33rd")
    }

    @Test func aLateLineKeepsItsDelayMark() {
        #expect(face(.minutes, board([4], delay: .minor))?.label == "33rd" + DelayLevel.minor.marker)
    }

    @Test func noTrainsMeansNoFace() {
        #expect(face(.minutes, Board(station: .journalSquare, rows: [])) == nil)
        // A line with nothing left is skipped for the one that has trains.
        #expect(face(.minutes, board([], [6]))?.label == "WTC")
    }

    @Test func redrawsEveryWholeMinute() {
        let start = now.addingTimeInterval(20)
        let dates = RoundFace.minuteDates(from: start, until: start.addingTimeInterval(5 * 60))
        #expect(dates.first == start)
        #expect(dates.count == 6)
        #expect(dates.dropFirst().allSatisfy { $0.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60) == 0 })
    }
}

/// Presets and their edits live in the app's defaults, so these put back what they found.
@MainActor @Suite(.serialized) struct PresetEditTests {
    private static let keys = ["customWidgetPreset", "customRoundPreset", "widgetPresetID", "widgetPresetEdits", "roundPresetID", "roundPresetEdits"]

    private func keepingDefaults(_ body: () throws -> Void) rethrows {
        let saved = Self.keys.map { UserDefaults.standard.object(forKey: $0) }
        let look = SharedStore.widgetLook, round = SharedStore.roundLook
        defer {
            for (key, value) in zip(Self.keys, saved) { UserDefaults.standard.set(value, forKey: key) }
            SharedStore.widgetLook = look
            SharedStore.roundLook = round
        }
        Self.keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        SharedStore.widgetLook = WidgetLook()
        SharedStore.roundLook = RoundLook()
        try body()
    }

    @Test func anEditStaysWithItsPresetOnceSaved() {
        keepingDefaults {
            let model = AppModel()
            #expect(model.presetID == "default" && model.roundPresetID == "minutes")
            #expect(!model.canRestorePreset(.rectangle))

            // An edit changes the preset in hand, not some other card.
            model.look.style.maxTimes = 1
            #expect(model.presetID == "default")
            #expect(model.isEdited(preset: "default", shape: .rectangle))
            #expect(model.hasUnsavedLook)
            model.saveLook()
            #expect(!model.hasUnsavedLook)
            #expect(model.presets.edits["default"] == WidgetLook(style: WidgetStyle(maxTimes: 1)))
            #expect(SharedStore.widgetLook.style.maxTimes == 1)

            // Another preset is as built; coming back finds the saved edit.
            model.selectPreset("packed", shape: .rectangle)
            #expect(model.look == WidgetPreset.builtIn[1].look)
            #expect(model.isEdited(preset: "default", shape: .rectangle), "The card left behind still says Edited")
            model.selectPreset("default", shape: .rectangle)
            #expect(model.look.style.maxTimes == 1)

            // And it is still there on the next launch.
            let next = AppModel()
            #expect(next.presetID == "default" && next.look.style.maxTimes == 1)
            #expect(next.presets.edits.count == 1)
        }
    }

    @Test func turningToAnotherPresetDropsWhatWasNotSaved() {
        keepingDefaults {
            let model = AppModel()
            model.look.font = .serif
            model.selectPreset("large", shape: .rectangle)
            #expect(model.look(forPreset: "default") == WidgetLook(), "The unsaved change is gone")
            #expect(!model.isEdited(preset: "default", shape: .rectangle))

            // The same on the round widget, which keeps its own.
            model.roundLook.skipNext = true
            model.selectPreset("clock", shape: .round)
            #expect(model.roundLook == RoundPreset.builtIn[1].look)
            #expect(!model.isEdited(preset: "minutes", shape: .round))

            // Cancel goes back to the presets the widgets are on.
            model.revertLook()
            #expect(model.presetID == "default" && model.roundPresetID == "minutes")
            #expect(!model.hasUnsavedLook)
        }
    }

    @Test func restorePresetIsAnEditLikeAnyOther() {
        keepingDefaults {
            let model = AppModel()
            model.roundLook.font = .serif
            model.saveLook()
            #expect(model.canRestorePreset(.round))
            #expect(!model.canRestorePreset(.rectangle))

            // Restoring shows in the preview and waits for Save; Cancel undoes it.
            model.restorePreset(.round)
            #expect(model.roundLook == RoundLook())
            #expect(model.hasUnsavedLook)
            #expect(SharedStore.roundLook.font == .serif, "The widget keeps the edit until Save")
            model.revertLook()
            #expect(model.roundLook.font == .serif)

            model.restorePreset(.round)
            model.saveLook()
            #expect(model.roundPresets.edits.isEmpty)
            #expect(SharedStore.roundLook == RoundLook())
            #expect(!model.canRestorePreset(.round))
        }
    }

    @Test func saveSendsBothLooksAndCancelPutsBothBack() {
        keepingDefaults {
            let model = AppModel()
            #expect(!model.hasUnsavedLook)
            model.selectPreset("ring", shape: .round)
            #expect(model.hasUnsavedLook)
            model.revertLook()
            #expect(model.roundLook == RoundLook())
            model.selectPreset("ring", shape: .round)
            model.selectPreset("packed", shape: .rectangle)
            model.saveLook()
            #expect(!model.hasUnsavedLook)
            #expect(SharedStore.roundLook == RoundPreset.builtIn[2].look)
            #expect(SharedStore.widgetLook == WidgetPreset.builtIn[1].look)
            #expect(model.presets.selected == "packed" && model.roundPresets.selected == "ring")
        }
    }

    @Test func restoreDefaultsClearsEditsUnlessPresetsAreKept() {
        keepingDefaults {
            let model = AppModel()
            model.selectPreset("packed", shape: .rectangle)
            model.look.style.compress = true
            model.saveLook()

            model.restoreDefaults(keeping: [.presets])
            #expect(model.presetID == "packed" && model.look.style.compress)
            #expect(model.presets.edits["packed"] != nil)

            model.restoreDefaults()
            #expect(model.presetID == "default" && model.look == WidgetLook())
            #expect(model.presets.edits.isEmpty)
            #expect(AppModel().presets.edits.isEmpty)
        }
    }

    // MARK: Taking over from older builds

    private let rectangles = WidgetPreset.builtIn.map { (id: $0.id, look: $0.look) }
    private let rounds = RoundPreset.builtIn.map { (id: $0.id, look: $0.look) }

    @Test func anOlderLookThatMatchesNoPresetBecomesEditsOnTheFirst() {
        let mine = WidgetLook(font: .rounded, style: WidgetStyle(density: .regular))
        let book = PresetBook.resolve(saved: mine, storedID: nil, storedEdits: [:], custom: mine, builtIn: rectangles, fallback: "default")
        #expect(book.selected == "default")
        #expect(book.edits == ["default": mine])
    }

    @Test func anOlderSpareCustomLookBecomesEditsOnTheFirst() {
        let mine = RoundLook(content: .minutes, font: .monospaced)
        let book = PresetBook.resolve(saved: RoundPreset.builtIn[1].look, storedID: nil, storedEdits: [:], custom: mine, builtIn: rounds, fallback: "minutes")
        #expect(book.selected == "clock", "The widget stays on the preset it shows")
        #expect(book.edits == ["minutes": mine])

        // The first preset cannot be both in use as built and edited: what shows is kept.
        let onFirst = PresetBook.resolve(saved: RoundLook(), storedID: nil, storedEdits: [:], custom: mine, builtIn: rounds, fallback: "minutes")
        #expect(onFirst.selected == "minutes" && onFirst.edits.isEmpty)
    }

    @Test func whatTheWidgetDrawsWinsOverAStaleBook() {
        // The stored book says Packed as built, but the widget has something else.
        let drawn = WidgetLook(font: .condensed, style: WidgetStyle(density: .compact, timeFormat: .short, maxTimes: 2))
        let book = PresetBook.resolve(saved: drawn, storedID: "packed", storedEdits: ["gone": WidgetLook(), "default": WidgetLook()],
                                      custom: nil, builtIn: rectangles, fallback: "default")
        #expect(book.selected == "packed")
        #expect(book.edits == ["packed": drawn], "Edits for presets that no longer exist, or that change nothing, are dropped")
    }

    @Test func theOlderCustomLookIsReadFromItsOldKey() throws {
        try keepingDefaults {
            let old = OldCustomPreset(look: WidgetLook(font: .rounded, style: WidgetStyle(density: .regular)))
            UserDefaults.standard.set(try JSONEncoder().encode(old), forKey: "customWidgetPreset")
            SharedStore.widgetLook = WidgetPreset.builtIn[1].look
            let model = AppModel()
            #expect(model.presetID == "packed")
            #expect(model.look(forPreset: "default") == old.look)
            #expect(UserDefaults.standard.object(forKey: "customWidgetPreset") == nil, "The old key is used once")
        }
    }

    @Test func aLookSavedBeforeAnOptionExistedStillReads() throws {
        let old = Data(#"{"font":"serif","style":{"density":"regular","timeFormat":"short","showArrival":true,"maxTimes":4}}"#.utf8)
        let look = try JSONDecoder().decode(WidgetLook.self, from: old)
        #expect(look == WidgetLook(font: .serif, style: WidgetStyle(density: .regular, timeFormat: .short, showArrival: true, maxTimes: 4)))
        #expect(look.style.showsHeader && !look.style.skipNext && !look.style.showsPeriod && !look.style.compress)
        let round = try JSONDecoder().decode(RoundLook.self, from: Data(#"{"content":"clock","font":"rounded"}"#.utf8))
        #expect(round == RoundLook(content: .clock, font: .rounded))
    }
}

@Suite("Round look options")
struct RoundOptionTests {
    let now = Fixture.date("2026-11-24 07:01")

    private func board(_ look: RoundLook) -> Board {
        var plan = BoardPlan(station: .journalSquare, schedule: Fixture.schedule, now: now)
        plan.style = look.boardStyle
        return plan.board(at: now)
    }

    @Test func skippingTheNextTrainFollowsTheSecond() throws {
        let plain = try #require(RoundFace.make(board: board(RoundLook()), content: .minutes, line: nil, now: now))
        var look = RoundLook()
        look.skipNext = true
        let skipped = try #require(RoundFace.make(board: board(look), content: .minutes, line: nil, now: now))
        #expect(plain.value == "9" && skipped.value == "19")
    }

    @Test func onlyAClockTimeHasAPeriod() throws {
        var look = RoundLook(content: .clock)
        look.showsPeriod = true
        #expect(look.hasClock && !RoundLook().hasClock)
        let clock = try #require(RoundFace.make(board: board(look), content: .clock, line: nil, now: now, showsPeriod: true))
        #expect(clock.value == "7:10" && clock.unit == "AM")
        let minutes = try #require(RoundFace.make(board: board(look), content: .minutes, line: nil, now: now, showsPeriod: true))
        #expect(minutes.unit == "min")
    }
}
