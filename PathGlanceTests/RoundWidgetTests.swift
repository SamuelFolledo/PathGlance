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

/// Custom looks live in the app's defaults, so these put back what they found.
@MainActor @Suite(.serialized) struct CustomPresetTests {
    private static let keys = ["customWidgetPreset", "customRoundPreset"]

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

    @Test func eachShapeRemembersItsOwnCustomLook() {
        keepingDefaults {
            let model = AppModel()
            #expect(model.customPreset == nil)
            #expect(model.customRoundPreset == nil)

            // Changing a built-in preset makes it the custom look at once, before any Save.
            model.look.style.maxTimes = 1
            #expect(model.customPreset?.look == WidgetLook(style: WidgetStyle(maxTimes: 1)))
            #expect(model.customRoundPreset == nil)

            model.roundLook.font = .monospaced
            #expect(model.customRoundPreset?.look == RoundLook(content: .minutes, font: .monospaced))
            #expect(model.customPreset?.look == WidgetLook(style: WidgetStyle(maxTimes: 1)))

            // Moving on to a built-in preset keeps both.
            model.look = WidgetPreset.builtIn[2].look
            model.roundLook = RoundPreset.builtIn[1].look
            #expect(model.customPreset?.look == WidgetLook(style: WidgetStyle(maxTimes: 1)))
            #expect(model.customRoundPreset?.look.font == .monospaced)

            // And they are still there on the next launch.
            let next = AppModel()
            #expect(next.customPreset?.look == WidgetLook(style: WidgetStyle(maxTimes: 1)))
            #expect(next.customRoundPreset?.look.font == .monospaced)
        }
    }

    @Test func theOlderSingleCustomLookBecomesTheRectangles() throws {
        try keepingDefaults {
            let old = AppModel.CustomPreset(look: WidgetLook(font: .rounded, style: WidgetStyle(density: .regular)), savedAt: Date())
            UserDefaults.standard.set(try JSONEncoder().encode(old), forKey: "customWidgetPreset")
            let model = AppModel()
            #expect(model.customPreset?.look == old.look)
            #expect(model.customRoundPreset == nil)
        }
    }

    @Test func saveSendsBothLooksAndCancelPutsBothBack() {
        keepingDefaults {
            let model = AppModel()
            #expect(!model.hasUnsavedLook)
            model.roundLook = RoundPreset.builtIn[2].look
            #expect(model.hasUnsavedLook)
            model.revertLook()
            #expect(model.roundLook == RoundLook())
            model.roundLook = RoundPreset.builtIn[2].look
            model.look = WidgetPreset.builtIn[1].look
            model.saveLook()
            #expect(!model.hasUnsavedLook)
            #expect(SharedStore.roundLook == RoundPreset.builtIn[2].look)
            #expect(SharedStore.widgetLook == WidgetPreset.builtIn[1].look)
        }
    }
}
