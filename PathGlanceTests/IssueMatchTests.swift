import Foundation
import Testing
@testable import PathGlance

@Suite("Issue matching")
struct IssueMatchTests {
    private func issue(_ title: String, _ message: String, kind: IssueKind = .delay, lines: [String] = []) -> PathGlance.Issue {
        PathGlance.Issue(id: title, kind: kind, title: title,
              updates: [IssueUpdate(id: 1, date: Fixture.date("2026-11-21 16:12"), subject: title, message: message)],
              startedAt: Fixture.date("2026-11-21 16:12"), affectedLines: lines)
    }

    @Test func aLineCodeIsNotAlsoItsEndStations() {
        let place = IssueMatcher.place(in: "04:12 PM: JSQ-33, HOB-33 delayed. Dispatch has reported signal problem at 33 St.")
        #expect(place.lines == ["JSQ-33", "HOB-33"])
        #expect(place.stations == [.thirtyThirdStreet])
    }

    @Test func stationsAreReadByNameAndShortForm() {
        #expect(IssueMatcher.place(in: "PATH Journal Square elevator is out of service.").stations == [.journalSquare])
        #expect(IssueMatcher.place(in: "JSQ elevator is temporarily out of service").stations == [.journalSquare])
        #expect(IssueMatcher.place(in: "PAPD responding at Grove St.").stations == [.groveStreet])
        #expect(IssueMatcher.place(in: "Escalator at 14th Street and WTC").stations == [.fourteenthStreet, .worldTradeCenter])
    }

    @Test func onlyWholeWordsCount() {
        // "Hobart" is not Hoboken and "Newportal" is not Newport.
        #expect(IssueMatcher.place(in: "Hobart Newportal 233 st").stations.isEmpty)
    }

    @Test func delayedLinesWinOverLinesOnlyMentioned() {
        let place = IssueMatcher.place(in: "NWK-WTC delayed. JSQ-33 running normally.", affectedLines: ["NWK-WTC"])
        #expect(place.lines == ["NWK-WTC"])
    }

    @Test func linesBetweenTwoStations() {
        #expect(IssueMatcher.lines(from: .journalSquare, to: .thirtyThirdStreet) == ["JSQ-33"])
        #expect(IssueMatcher.lines(from: .journalSquare, to: .worldTradeCenter) == ["NWK-WTC"])
        #expect(IssueMatcher.lines(from: .hoboken, to: .thirtyThirdStreet) == ["HOB-33", "JSQ-33"])
    }

    @Test func anIssueAtYourStationIsYours() {
        let elevator = issue("JSQ elevator is temporarily out of service", "PATH Journal Square elevator is out of service.", kind: .elevator)
        #expect(IssueMatcher.relevance(of: elevator, station: .journalSquare, target: .thirtyThirdStreet) == .station)
        #expect(IssueMatcher.relevance(of: elevator, station: .hoboken, target: .thirtyThirdStreet) == nil)
    }

    @Test func anIssueOnTheLineToYourDestinationIsYours() {
        let signal = issue("Signal Problem", "JSQ-33 delayed. Signal problem at 33 St.", lines: ["JSQ-33"])
        #expect(IssueMatcher.relevance(of: signal, station: .journalSquare, target: .thirtyThirdStreet) == .line)
        #expect(IssueMatcher.relevance(of: signal, station: .journalSquare, target: .worldTradeCenter) == nil)
        #expect(IssueMatcher.relevance(of: signal, station: .journalSquare, target: nil) == nil)
    }

    @Test func textThatNamesNothingMatchesNothing() {
        let vague = issue("Service Advisory", "Expect crowding this evening.", kind: .other)
        #expect(IssueMatcher.place(of: vague) == IssuePlace())
        #expect(IssueMatcher.relevance(of: vague, station: .journalSquare, target: .thirtyThirdStreet) == nil)
    }

    @Test func aDelayTheAppNoticedCarriesItsOwnPlace() {
        var late = issue("J Sq to 33rd running late", "Live arrivals are about 8 min behind the timetable.")
        late.id = "live-journalSquare-thirtyThirdStreet-1795300000"
        late.detected = true
        #expect(IssueMatcher.relevance(of: late, station: .journalSquare, target: .thirtyThirdStreet) == .line)
        #expect(IssueMatcher.relevance(of: late, station: .journalSquare, target: .worldTradeCenter) == nil)
    }
}
