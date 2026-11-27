import Foundation
import Testing
@testable import PathGlance

@Suite("Issues laid out by line and stop")
struct IssueBoardTests {
    private func issue(_ id: String, _ message: String, kind: IssueKind = .delay, lines: [String] = []) -> PathGlance.Issue {
        PathGlance.Issue(id: id, kind: kind, title: id,
              updates: [IssueUpdate(id: 1, date: Fixture.date("2026-11-21 16:12"), subject: id, message: message)],
              startedAt: Fixture.date("2026-11-21 16:12"), affectedLines: lines)
    }

    @Test func aLineIssueSitsAtTheStopsItNames() {
        let signal = issue("signal", "JSQ-33 delayed. Signal problem at Grove St.", lines: ["JSQ-33"])
        let strip = IssueBoard.strip("JSQ-33", issues: [signal])
        #expect(strip.wholeLine.isEmpty)
        #expect(strip.stops.first { $0.station == .groveStreet }?.issues == [signal])
        #expect(strip.stops.filter { !$0.issues.isEmpty }.count == 1)
        // Grove Street is on NWK-WTC too, but the issue names only JSQ-33.
        #expect(IssueBoard.strip("NWK-WTC", issues: [signal]).issues.isEmpty)
    }

    @Test func aLineIssueWithNoStopIsTheWholeLines() {
        let late = issue("late", "NWK-WTC delayed up to 10 min.", lines: ["NWK-WTC"])
        let strip = IssueBoard.strip("NWK-WTC", issues: [late])
        #expect(strip.wholeLine == [late])
        #expect(strip.stops.allSatisfy { $0.issues.isEmpty })
    }

    @Test func aStationIssueShowsOnEveryLineThatCallsThere() {
        let lift = issue("lift", "Journal Square elevator is out of service.", kind: .elevator)
        #expect(IssueBoard.strip("JSQ-33", issues: [lift]).stops.first?.issues == [lift])
        #expect(IssueBoard.strip("NWK-WTC", issues: [lift]).stops.first { $0.station == .journalSquare }?.issues == [lift])
        #expect(IssueBoard.strip("HOB-33", issues: [lift]).issues.isEmpty)
        #expect(IssueBoard.other([lift]).isEmpty)
    }

    @Test func whatNamesNothingIsOther() {
        let notice = issue("notice", "The customer service line is closed for the holiday.", kind: .other)
        #expect(IssueBoard.other([notice]) == [notice])
        for code in PathLines.stations.keys {
            #expect(IssueBoard.strip(code, issues: [notice]).issues.isEmpty)
        }
    }

    @Test func hobokenIsDrawnOnJournalSquareTo33rdOnlyWhenAnIssueThereNamesIt() {
        #expect(!IssueBoard.strip("JSQ-33", issues: []).stops.map(\.station).contains(.hoboken))
        // A Hoboken elevator is not about this line.
        let lift = issue("lift", "Hoboken elevator is out of service.", kind: .elevator)
        #expect(!IssueBoard.strip("JSQ-33", issues: [lift]).stops.map(\.station).contains(.hoboken))
        let via = issue("via", "JSQ-33 via HOB trains delayed at Hoboken.", lines: ["JSQ-33"])
        let strip = IssueBoard.strip("JSQ-33", issues: [via])
        #expect(strip.stops.first { $0.station == .hoboken }?.issues == [via])
        #expect(IssueBoard.strip("HOB-33", issues: []).stops.first?.station == .hoboken)
    }

    @Test func aTabCountsItsLinesUnmutedIssuesOnce() {
        let signal = issue("signal", "JSQ-33, HOB-33 delayed. Signal problem at 33 St.", lines: ["JSQ-33", "HOB-33"])
        let lift = issue("lift", "Hoboken elevator is out of service.", kind: .elevator)
        let notice = issue("notice", "Fare gates are being replaced.", kind: .other)
        let all = [signal, lift, notice]
        #expect(IssueBoard.count(.journalSquare33, issues: all, muted: []) == 1)
        // The elevator is at Hoboken on both Hoboken lines, and counts once.
        #expect(IssueBoard.count(.hoboken, issues: all, muted: []) == 2)
        #expect(IssueBoard.count(.hoboken, issues: all, muted: [.elevator]) == 1)
        #expect(IssueBoard.count(.newarkWorldTrade, issues: all, muted: []) == 0)
    }

    @Test func tabsFollowTheLinesPreferred() {
        #expect(IssueBoard.tabs(order: BoardRules.terminals) == [.journalSquare33, .newarkWorldTrade, .hoboken])
        #expect(IssueBoard.tabs(order: [.worldTradeCenter, .hoboken, .thirtyThirdStreet, .journalSquare, .newark])
                == [.newarkWorldTrade, .hoboken, .journalSquare33])
    }

    @Test func aDelayTheAppNoticedSitsAtItsStation() {
        let seen = PathGlance.Issue(id: "live-journalSquare-thirtyThirdStreet-1", kind: .delay, title: "J Sq to 33rd running late",
                                    updates: [], startedAt: Fixture.date("2026-11-21 16:12"), detected: true)
        #expect(IssueBoard.strip("JSQ-33", issues: [seen]).stops.first?.issues == [seen])
        #expect(IssueBoard.strip("NWK-WTC", issues: [seen]).issues.isEmpty)
    }
}
