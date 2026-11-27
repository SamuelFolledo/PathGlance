import Testing
import SwiftUI
@testable import PathGlance

struct PreferenceTests {
    // MARK: Lines preferred

    @Test func theStandardOrderChangesNothing() {
        #expect(BoardRules.widgetTargets(from: .journalSquare, hidden: [], order: BoardRules.terminals) == [.thirtyThirdStreet, .worldTradeCenter])
        // Newport's tabs are not in terminal order, and stay as they were.
        let tabs = BoardRules.destinations(from: .newport, hidden: [], schedule: Fixture.schedule)
        #expect(BoardRules.destinations(from: .newport, hidden: [], order: BoardRules.terminals, schedule: Fixture.schedule) == tabs)
    }

    @Test func aPreferredLineLeadsTheWidgetAndTheTabs() {
        let order: [Station] = [.worldTradeCenter, .newark, .thirtyThirdStreet, .journalSquare, .hoboken]
        #expect(BoardRules.widgetTargets(from: .journalSquare, hidden: [], order: order) == [.worldTradeCenter, .thirtyThirdStreet])
        #expect(BoardRules.destinations(from: .journalSquare, hidden: [], order: order, schedule: Fixture.schedule) == [.worldTradeCenter, .newark, .thirtyThirdStreet])
        // The order never adds a line to the widget: Newark is a tab here, not a widget row.
        #expect(!BoardRules.widgetTargets(from: .journalSquare, hidden: [], order: order).contains(.newark))
    }

    @Test func hidingStillWinsOverTheOrder() {
        let order: [Station] = [.worldTradeCenter, .thirtyThirdStreet]
        #expect(BoardRules.widgetTargets(from: .journalSquare, hidden: [.worldTradeCenter], order: order) == [.thirtyThirdStreet])
        // A station whose only line is hidden still shows it.
        #expect(BoardRules.widgetTargets(from: .newark, hidden: [.worldTradeCenter], order: order) == [.worldTradeCenter])
    }

    @Test func aStoredOrderIsMadeWhole() {
        #expect(BoardRules.completed([]) == BoardRules.terminals)
        #expect(BoardRules.completed([.newark, .newark, .groveStreet]) == [.newark, .thirtyThirdStreet, .worldTradeCenter, .journalSquare, .hoboken])
    }

    // MARK: Text size

    @Test func theAppFollowsThePhonesTextSize() {
        #expect(AppModel.textSize(system: .large, offset: 0) == .xLarge)
        #expect(AppModel.textSize(system: .xxLarge, offset: 0) == .xxxLarge)
        #expect(AppModel.textSize(system: .large, offset: 2) == .xxxLarge)
        #expect(AppModel.textSize(system: .large, offset: -1) == .large)
    }

    @Test func textSizeStaysWithinWhatTheLayoutsTake() {
        #expect(AppModel.textSize(system: .accessibility5, offset: 3) == .accessibility1)
        #expect(AppModel.textSize(system: .xSmall, offset: -3) == .small)
        #expect(AppModel.textSize(system: .large, offset: 3) == .accessibility1)
    }

    @Test func textSizeIsNamedByItsOffset() {
        #expect(AppModel.textSizeName(offset: 0) == "Standard")
        #expect(AppModel.textSizeName(offset: 2) == "+2")
        #expect(AppModel.textSizeName(offset: -1) == "−1")
    }

    // MARK: Columns

    @Test func theTrainListKeepsTwoColumns() {
        #expect(!AppModel.canHideColumn(visible: 1))
        #expect(AppModel.canHideColumn(visible: 2))
    }

    // MARK: Restore defaults

    @Test func restoreAsksWhatToKeepWithNothingTicked() {
        var kept: Set<SharedStore.Kept>?
        let guide = SettingsSheet.restoreGuide { kept = $0 }
        #expect(guide.options.map(\.id) == ["favoriteStops", "mutedIssues", "presets"])
        #expect(!guide.canBeSilenced)
        guide.onConfirm?(["mutedIssues", "nonsense"])
        #expect(kept == [.mutedIssues])
    }

    @Test func eachKeptThingSparesItsOwnKeys() {
        #expect(SharedStore.Kept.favoriteStops.keys == ["favoriteStops"])
        #expect(SharedStore.Kept.mutedIssues.keys == ["mutedIssueKinds"])
        #expect(SharedStore.Kept.presets.keys.contains("fontStyle") && SharedStore.Kept.presets.keys.contains("roundContent"))
        // Everything a kept thing names is a key "Restore defaults" would otherwise clear.
        for kept in SharedStore.Kept.allCases {
            #expect(kept.keys.isSubset(of: Set(SharedStore.preferenceKeys)))
        }
        #expect(SharedStore.preferenceKeys.contains("lineOrder"))
    }

    // MARK: Issue text

    @Test func anUpdateDropsTheTimePathPutsInFront() {
        #expect(IssueUpdate.withoutLeadingTime("04:12 PM: JSQ-33, HOB-33 delayed.") == "JSQ-33, HOB-33 delayed.")
        #expect(IssueUpdate.withoutLeadingTime("9:02PM - NWK-WTC delayed.") == "NWK-WTC delayed.")
        #expect(IssueUpdate.withoutLeadingTime("11/21 04:12 PM: Signal problem.") == "Signal problem.")
        // A time further in, or a range of hours, is part of the message.
        #expect(IssueUpdate.withoutLeadingTime("Weekend Daytime Service (10am-9pm): HOB-WTC 20m.") == "Weekend Daytime Service (10am-9pm): HOB-WTC 20m.")
        #expect(IssueUpdate.withoutLeadingTime("Trains resume at 6:13 PM: expect delays.") == "Trains resume at 6:13 PM: expect delays.")
    }

    @Test func anEmptyUpdateFallsBackToItsSubject() {
        let update = IssueUpdate(id: 1, date: Date(), subject: "PATHAlert: Signal Problem", message: "04:12 PM: ")
        #expect(update.body == "PATHAlert: Signal Problem")
    }
}
