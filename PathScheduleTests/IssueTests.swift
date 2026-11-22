import Foundation
import Testing
@testable import PathSchedule

@Suite("Issues")
struct IssueTests {
    /// One entry in the shape of PATH's alert feed.
    private func alert(_ id: Int, incident: Int, subject: String, message: String, template: String, open: Bool, sent: String) -> [String: Any] {
        ["messageid": id, "ebid": incident, "Subject": subject, "SentMessage": message, "TemplateName": template,
         "state": open ? "Open" : "Closed", "sentdate2": "/Date(\(Int(Fixture.date(sent).timeIntervalSince1970 * 1000)))/",
         "SentTo": "PATH", "NumSent": 0]
    }

    private func decode(_ entries: [[String: Any]]) throws -> [PathAlert] {
        try JSONDecoder().decode([PathAlert].self, from: JSONSerialization.data(withJSONObject: entries))
    }

    private var feed: [[String: Any]] {
        [
            alert(1, incident: 100, subject: "PATHAlert: Signal Problem", message: "04:12 PM: JSQ-33, HOB-33 delayed. Dispatch has reported signal problem at 33 St.", template: "PATH - Signal Problem", open: false, sent: "2026-11-21 16:12"),
            alert(2, incident: 100, subject: "PATHAlert Update: Signal Problems", message: "04:19 PM: JSQ-33, HOB-33 suspended. Maintenance dispatched.", template: "PATH - Signal Problem", open: false, sent: "2026-11-21 16:19"),
            alert(3, incident: 100, subject: "PATHAlert Final Update: Signal Problems", message: "06:13 PM: JSQ-33, HOB-33 resuming normal service.", template: "PATH - Signal Problem", open: false, sent: "2026-11-21 18:13"),
            alert(4, incident: 200, subject: "JSQ elevator is temporarily out of service", message: "06:51 PM: PATH Journal Square elevator is out of service.", template: "PATH Elevator - Journal Square", open: true, sent: "2026-11-21 18:51"),
            alert(5, incident: 300, subject: "PATH Sat 11/21 Planned Weekend Service", message: "Weekend Daytime Service (10am-9pm): HOB-WTC 20m.", template: "PATH - Planned Service Advisory", open: true, sent: "2026-11-21 19:19"),
            alert(6, incident: 400, subject: "PATHAlert: Police Activity", message: "09:02 PM: NWK-WTC delayed. PAPD responding at Grove St. JSQ-33 running normally.", template: "PATH - PAPD General Notification", open: true, sent: "2026-11-21 21:02"),
        ]
    }

    @Test func feedEntriesDecode() throws {
        let alerts = try decode(feed)
        #expect(alerts.count == 6)
        #expect(alerts[0].incidentID == "100")
        #expect(alerts[0].sent == Fixture.date("2026-11-21 16:12"))
        #expect(alerts[3].isOpen)
        #expect(!alerts[0].isOpen)
    }

    @Test func updatesAboutOneIncidentBecomeOneIssue() throws {
        var log = IssueLog()
        log.merge(alerts: try decode(feed), now: Fixture.date("2026-11-21 21:10"))
        #expect(log.issues.count == 4)

        let signal = try #require(log.archived.first { $0.id == "100" })
        #expect(signal.kind == .suspension) // the worst it got
        #expect(signal.title == "Signal Problem")
        #expect(signal.updates.count == 3)
        #expect(signal.startedAt == Fixture.date("2026-11-21 16:12"))
        #expect(signal.endedAt == Fixture.date("2026-11-21 18:13"))
        #expect(signal.affectedLines.isEmpty)
    }

    @Test func openIssuesAreSortedNewestFirstAndClassified() throws {
        var log = IssueLog()
        log.merge(alerts: try decode(feed), now: Fixture.date("2026-11-21 21:10"))
        #expect(log.active.map(\.kind) == [.delay, .plannedWork, .elevator])
        let police = try #require(log.active.first)
        // Only the line reported as delayed, not the one "running normally".
        #expect(police.affectedLines == ["NWK-WTC"])
        #expect(police.affects(from: .harrison, to: .worldTradeCenter))
        #expect(!police.affects(from: .ninthStreet, to: .thirtyThirdStreet))
    }

    @Test func anIssueThatLeavesTheFeedIsArchivedNow() throws {
        var log = IssueLog()
        log.merge(alerts: try decode(feed), now: Fixture.date("2026-11-21 21:10"))
        let later = Fixture.date("2026-11-21 22:00")
        log.merge(alerts: try decode(feed.filter { ($0["ebid"] as? Int) != 400 }), now: later)
        let police = try #require(log.issues.first { $0.id == "400" })
        #expect(police.endedAt == later)
        #expect(!log.active.contains { $0.id == "400" })
    }

    @Test func mergingTheSameFeedTwiceChangesNothing() throws {
        var log = IssueLog()
        let alerts = try decode(feed)
        log.merge(alerts: alerts, now: Fixture.date("2026-11-21 21:10"))
        let first = log.issues.sorted { $0.id < $1.id }
        log.merge(alerts: alerts, now: Fixture.date("2026-11-21 21:30"))
        #expect(log.issues.sorted { $0.id < $1.id } == first)
    }

    @Test func oldArchivedIssuesAreDropped() throws {
        var log = IssueLog()
        log.merge(alerts: try decode(feed), now: Fixture.date("2026-11-21 21:10"))
        // Long after: the signal problem that ended in 2026 is gone. The three that were
        // still open only end now, so they stay.
        log.merge(alerts: [], now: Fixture.date("2028-02-01 12:00"))
        #expect(!log.issues.contains { $0.id == "100" })
        #expect(log.issues.count == 3)
        #expect(log.active.isEmpty)
    }

    @Test func affectedLinesComeFromDelayAndSuspensionSentences() {
        #expect(PathLines.affected(in: "04:55 PM: JSQ-33, HOB-33 resuming with delays. Work is ongoing.") == ["HOB-33", "JSQ-33"])
        #expect(PathLines.affected(in: "06:13 PM: JSQ-33, HOB-33 resuming normal service.") == [])
        #expect(PathLines.affected(in: "NWK-WTC suspended. HOB-WTC running normally.") == ["NWK-WTC"])
    }

    @Test func delaysTheAppNoticesOpenAndCloseTheirOwnIssue() throws {
        var log = IssueLog()
        let start = Fixture.date("2026-11-28 07:15")
        log.noteDetectedDelays([(origin: .journalSquare, target: .thirtyThirdStreet, minutes: 12)], at: .journalSquare, now: start)
        #expect(log.active.count == 1)
        #expect(log.active[0].detected)
        #expect(log.active[0].kind == .delay)

        // Still late at the next check: the same issue gains an update.
        log.noteDetectedDelays([(origin: .journalSquare, target: .thirtyThirdStreet, minutes: 15)], at: .journalSquare, now: start.addingTimeInterval(1200))
        #expect(log.issues.count == 1)
        #expect(log.active[0].updates.count == 2)

        // A check from another station says nothing about Journal Square.
        log.noteDetectedDelays([], at: .hoboken, now: start.addingTimeInterval(1500))
        #expect(log.active.count == 1)

        log.noteDetectedDelays([], at: .journalSquare, now: start.addingTimeInterval(2400))
        #expect(log.active.isEmpty)
        #expect(log.archived[0].endedAt == start.addingTimeInterval(2400))

        // PATH's feed dropping out does not close an issue the app found itself, and vice versa.
        log.noteDetectedDelays([(origin: .journalSquare, target: .thirtyThirdStreet, minutes: 11)], at: .journalSquare, now: start.addingTimeInterval(3000))
        log.merge(alerts: [], now: start.addingTimeInterval(3100))
        #expect(log.active.count == 1)
    }
}

@Suite("Day types and holidays")
struct DayTypeTests {
    @Test func holidaysFallOnTheRightDates() {
        #expect(Holiday.thanksgiving.ymd(in: 2026) == 20261126)
        #expect(Holiday.thanksgiving.ymd(in: 2025) == 20251127)
        #expect(Holiday.dayAfterThanksgiving.ymd(in: 2026) == 20261127)
        #expect(Holiday.mlkDay.ymd(in: 2026) == 20260119)
        #expect(Holiday.presidentsDay.ymd(in: 2026) == 20260216)
        #expect(Holiday.memorialDay.ymd(in: 2026) == 20260525)
        #expect(Holiday.laborDay.ymd(in: 2026) == 20260907)
        #expect(Holiday.independenceDay.ymd(in: 2027) == 20270704)
        #expect(Holiday.on(ymd: 20261225) == .christmas)
        #expect(Holiday.on(ymd: 20261124) == nil)
    }

    @Test func theCalendarGivesTheNormalDayType() {
        #expect(DayType.normal(forYMD: 20261124) == .weekday)
        #expect(DayType.normal(forYMD: 20261128) == .saturday)
        #expect(DayType.normal(forYMD: 20261129) == .sunday)
    }

    /// Live arrivals that follow the given day type's timetable, as seen at `time`.
    private func arrivals(following type: DayType, at time: Date) -> [RealtimeArrival] {
        var schedule = Fixture.schedule
        schedule.dayOverrides = [PathTime.ymd(of: time): type.rawValue]
        let pairs: [(Station, Station, String)] = [
            (.journalSquare, .thirtyThirdStreet, "33rd Street"), (.journalSquare, .worldTradeCenter, "World Trade Center"),
            (.hoboken, .thirtyThirdStreet, "33rd Street"), (.newark, .worldTradeCenter, "World Trade Center"),
            (.worldTradeCenter, .newark, "Newark"), (.thirtyThirdStreet, .journalSquare, "Journal Square"),
            (.groveStreet, .worldTradeCenter, "World Trade Center"), (.exchangePlace, .newark, "Newark"),
        ]
        return pairs.flatMap { origin, target, sign in
            schedule.departures(from: origin, to: target, after: time, limit: 2).map { RealtimeArrival(station: origin, headSign: sign, arrival: $0.time) }
        }
    }

    @Test func liveTrainsOnTheSundayTimetableAreRecognisedOnAHoliday() {
        var log = DayTypeLog()
        // Thanksgiving 2026, a Thursday, running Sunday service.
        for hour in 7...12 {
            let time = Fixture.date(String(format: "2026-11-26 %02d:07", hour))
            log.record(arrivals: arrivals(following: .sunday, at: time), schedule: Fixture.schedule, now: time)
        }
        let day = log.days["20261126"]
        #expect((day?.samples ?? 0) >= DayTypeLog.minimumSamples)
        #expect(day?.matched == .sunday)
        let resolution = log.resolution(forYMD: 20261126)
        #expect(resolution?.type == .sunday)
        #expect(resolution?.note == "Thanksgiving: live trains match the Sunday timetable")
        #expect(log.overrides(around: Fixture.date("2026-11-26 12:00")) == [20261126: DayType.sunday.rawValue])
    }

    @Test func anOrdinaryDayKeepsItsTimetable() {
        var log = DayTypeLog()
        for hour in 7...12 {
            let time = Fixture.date(String(format: "2026-11-24 %02d:07", hour))
            log.record(arrivals: arrivals(following: .weekday, at: time), schedule: Fixture.schedule, now: time)
        }
        #expect(log.days["20261124"]?.matched == .weekday)
        #expect(log.resolution(forYMD: 20261124) == nil)
        #expect(log.overrides(around: Fixture.date("2026-11-24 12:00")).isEmpty)
    }

    @Test func tooLittleDataDecidesNothing() {
        var log = DayTypeLog()
        let time = Fixture.date("2026-11-26 07:07")
        log.record(arrivals: Array(arrivals(following: .sunday, at: time).prefix(5)), schedule: Fixture.schedule, now: time)
        #expect(log.days["20261126"]?.matched == nil)
        // A holiday with nothing to go on is flagged, on the calendar's timetable.
        #expect(log.resolution(forYMD: 20261126)?.note == "Thanksgiving: holiday timetable not known yet, showing Weekday")
    }

    @Test func overnightArrivalsAreNotCounted() {
        var log = DayTypeLog()
        let time = Fixture.date("2026-11-26 02:00")
        log.record(arrivals: arrivals(following: .sunday, at: time), schedule: Fixture.schedule, now: time)
        #expect((log.days["20261126"]?.samples ?? 0) == 0)
    }

    @Test func aHolidayStartsFromLastYearsAnswer() {
        var log = DayTypeLog()
        log.days["20251127"] = DayObservation(ymd: 20251127, samples: 200, errorSum: [900, 700, 150])
        let resolution = log.resolution(forYMD: 20261126)
        #expect(resolution?.type == .sunday)
        #expect(resolution?.note == "Thanksgiving: using 2025's timetable (Sunday) until live data is in")
        #expect(log.overrides(around: Fixture.date("2026-11-25 20:00"))[20261126] == DayType.sunday.rawValue)
        // The day before is an ordinary Wednesday.
        #expect(log.resolution(forYMD: 20261125) == nil)
    }

    @Test func todaysLiveDataBeatsLastYear() {
        var log = DayTypeLog()
        log.days["20251127"] = DayObservation(ymd: 20251127, samples: 200, errorSum: [900, 700, 150])
        // This year it clearly runs the Saturday timetable.
        log.days["20261126"] = DayObservation(ymd: 20261126, samples: 100, errorSum: [500, 80, 400])
        #expect(log.resolution(forYMD: 20261126)?.type == .saturday)
    }
}
