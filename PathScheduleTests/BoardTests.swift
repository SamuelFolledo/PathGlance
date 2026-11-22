import Foundation
import Testing
@testable import PathSchedule

@Suite("Board rules")
struct BoardRulesTests {
    @Test func stationRulesMatchTheTable() {
        #expect(BoardRules.targets(from: .journalSquare) == [.thirtyThirdStreet, .worldTradeCenter])
        for station in [Station.groveStreet, .newport, .christopherStreet, .ninthStreet, .fourteenthStreet, .twentyThirdStreet] {
            #expect(BoardRules.targets(from: station) == [.thirtyThirdStreet, .journalSquare])
        }
        #expect(BoardRules.targets(from: .thirtyThirdStreet) == [.journalSquare, .hoboken])
        #expect(BoardRules.targets(from: .worldTradeCenter) == [.newark])
        #expect(BoardRules.targets(from: .hoboken) == [.thirtyThirdStreet, .worldTradeCenter])
        #expect(BoardRules.targets(from: .exchangePlace) == [.worldTradeCenter, .journalSquare])
        #expect(BoardRules.targets(from: .newark) == [.worldTradeCenter])
        #expect(BoardRules.targets(from: .harrison) == [.worldTradeCenter])
    }

    @Test func hiddenDestinationsLeaveTheWidget() {
        #expect(BoardRules.widgetTargets(from: .journalSquare, hidden: [.worldTradeCenter]) == [.thirtyThirdStreet])
        // A station whose only line is turned off still shows it.
        #expect(BoardRules.widgetTargets(from: .newark, hidden: [.worldTradeCenter]) == [.worldTradeCenter])
        #expect(BoardRules.widgetTargets(from: .journalSquare, hidden: []) == [.thirtyThirdStreet, .worldTradeCenter])
    }

    @Test func destinationTabsListEveryReachableLineEnd() {
        let tabs = BoardRules.destinations(from: .journalSquare, hidden: [], schedule: Fixture.schedule)
        #expect(tabs == [.thirtyThirdStreet, .worldTradeCenter, .hoboken, .newark])
        let fewer = BoardRules.destinations(from: .journalSquare, hidden: [.hoboken, .worldTradeCenter], schedule: Fixture.schedule)
        #expect(fewer == [.thirtyThirdStreet, .newark])
        #expect(BoardRules.destinations(from: .thirtyThirdStreet, hidden: [], schedule: Fixture.schedule) == [.journalSquare, .hoboken])
    }
}

@Suite("Time formats")
struct CompactTimesTests {
    private let times = ["2026-11-24 19:10", "2026-11-24 19:30", "2026-11-24 19:50", "2026-11-24 20:00", "2026-11-24 20:10"].map(Fixture.date)

    @Test func shortFormDropsARepeatedHour() {
        #expect(CompactTimes.string(times, format: .short) == "7:10 :30 :50 8:00 :10")
    }

    @Test func fullFormWritesEveryTime() {
        #expect(CompactTimes.string(Array(times.prefix(3)), format: .full) == "7:10, 7:30, 7:50")
    }

    @Test func arrivalFollowsTheFirstTime() {
        let arrival = Fixture.date("2026-11-24 19:33")
        #expect(CompactTimes.string(Array(times.prefix(2)), arrivalOfFirst: arrival, format: .full) == "7:10→7:33, 7:30")
        #expect(CompactTimes.string(Array(times.prefix(2)), arrivalOfFirst: arrival, format: .short) == "7:10→:33 :30")
    }

    @Test func clocksUseTwelveHourNewYorkTime() {
        #expect(CompactTimes.clock(Fixture.date("2026-11-24 00:05")) == "12:05")
        #expect(CompactTimes.clockWithPeriod(Fixture.date("2026-11-24 00:05")) == "12:05 AM")
        #expect(CompactTimes.clockWithPeriod(Fixture.date("2026-11-24 12:00")) == "12:00 PM")
        #expect(CompactTimes.clockWithPeriod(Fixture.date("2026-11-24 19:05")) == "7:05 PM")
    }

    @Test func styleSetsHowManyTimesFit() {
        #expect(WidgetStyle(density: .compact, timeFormat: .short).timesPerLine == 5)
        #expect(WidgetStyle(density: .regular, timeFormat: .short).timesPerLine == 4)
        #expect(WidgetStyle(density: .compact, timeFormat: .full).timesPerLine == 4)
        #expect(WidgetStyle(density: .regular, timeFormat: .full).timesPerLine == 3)
        #expect(WidgetStyle().timeFormat == .full)
        #expect(WidgetStyle().density == .compact)
    }
}

@Suite("Board")
struct BoardPlanTests {
    let schedule = Fixture.schedule
    let now = Fixture.date("2026-11-24 07:01")

    private func plan(_ station: Station, targets: [Station]? = nil, at date: Date? = nil, style: WidgetStyle = WidgetStyle(timeFormat: .short)) -> BoardPlan {
        var plan = BoardPlan(station: station, targets: targets, schedule: schedule, now: date ?? now)
        plan.style = style
        return plan
    }

    @Test func twoDestinationsGetALineEach() {
        let board = plan(.journalSquare).board(at: now)
        #expect(board.lines.map(\.text) == ["33rd 7:10 :20 :30 :40 :50", "WTC 7:03 :13 :23 :33 :43"])
        #expect(board.lines.map(\.target) == [.thirtyThirdStreet, .worldTradeCenter])
        #expect(!board.hasAlert)
    }

    @Test func oneDestinationFillsBothLines() {
        let board = plan(.journalSquare, targets: [.thirtyThirdStreet]).board(at: now)
        #expect(board.lines.map(\.text) == ["33rd 7:10 :20 :30 :40 :50", "8:00 :10 :20 :30 :40"])
        // The second line still opens the same destination.
        #expect(board.lines.map(\.target) == [.thirtyThirdStreet, .thirtyThirdStreet])
    }

    @Test func sameTrainsForTwoDestinationsAreNamedTogether() {
        // Overnight every train from 33rd runs to Journal Square by way of Hoboken.
        let night = Fixture.date("2026-11-25 01:00")
        let board = plan(.thirtyThirdStreet, at: night).board(at: night)
        #expect(board.lines.first?.label == "JSQ+HOB")
        #expect(board.lines.count == 2)
        #expect(board.lines.last?.label == "")
    }

    @Test func fullTimesAndArrivalOnTheWidget() {
        let board = plan(.journalSquare, style: WidgetStyle(density: .regular, timeFormat: .full, showArrival: true)).board(at: now)
        #expect(board.lines.first?.text == "33rd 7:10→7:33, 7:20, 7:30")
    }

    @Test func trainsDropOffAMinuteAfterLeaving() {
        let board = plan(.journalSquare)
        #expect(board.board(at: Fixture.date("2026-11-24 07:10")).lines.first?.times.first == Fixture.date("2026-11-24 07:10"))
        #expect(board.board(at: Fixture.date("2026-11-24 07:12")).lines.first?.times.first == Fixture.date("2026-11-24 07:20"))
        let refresh = board.refreshDates(from: now)
        #expect(refresh.first == now)
        #expect(refresh.contains(Fixture.date("2026-11-24 07:11")))
        #expect(refresh.count <= 41)
    }

    @Test func noTrainsGivesAnEmptyBoard() {
        var empty = schedule
        empty.departures = [:]
        let board = BoardPlan(station: .journalSquare, schedule: empty, now: now).board(at: now)
        #expect(board.lines.isEmpty)
    }

    // MARK: Live arrivals

    @Test func liveTimesReplaceTheFirstScheduledOnes() {
        var live = plan(.journalSquare)
        live.apply(realtime: [Fixture.arrival(.journalSquare, "33rd Street", at: Fixture.date("2026-11-24 07:12"))], now: now)
        let line = live.board(at: now).lines[0]
        #expect(line.text == "33rd 7:12 :20 :30 :40 :50")
        #expect(line.delay == .none)
        #expect(live.groups[0].trains.first?.isLive == true)
    }

    @Test(arguments: [(4, DelayLevel.none), (5, .minor), (9, .minor), (10, .major), (16, .major)])
    func delayMarkersFollowHowLateTheTrainIs(minutes: Int, expected: DelayLevel) {
        // Saturdays run every 20 minutes, so a late train is not mistaken for the next one.
        let saturday = Fixture.date("2026-11-28 07:15")
        var live = plan(.journalSquare, at: saturday)
        let predicted = Fixture.date("2026-11-28 07:23").addingTimeInterval(TimeInterval(minutes * 60))
        live.apply(realtime: [Fixture.arrival(.journalSquare, "33rd Street", at: predicted)], now: saturday)
        #expect(live.groups[0].delay == expected)
        #expect(live.board(at: saturday).lines[0].label + live.board(at: saturday).lines[0].delay.marker == "33rd" + expected.marker)
    }

    @Test func aTrainNearlyAHeadwayLateLooksLikeTheNextOne() {
        // The known limit: 19 minutes late on a 20-minute line cannot be told from the
        // following train a minute early. PATH's alerts cover this case.
        let saturday = Fixture.date("2026-11-28 07:15")
        var live = plan(.journalSquare, at: saturday)
        live.apply(realtime: [Fixture.arrival(.journalSquare, "33rd Street", at: Fixture.date("2026-11-28 07:42"))], now: saturday)
        #expect(live.groups[0].delay == .none)
    }

    @Test func aLongGapIsNotADelay() {
        // Half an hour or more with no train is a break in service, not a late train.
        let sunday = Fixture.date("2026-11-29 07:35")
        var live = plan(.hoboken, targets: [.worldTradeCenter], at: sunday)
        live.apply(realtime: [Fixture.arrival(.hoboken, "World Trade Center", at: Fixture.date("2026-11-29 08:45"))], now: sunday)
        #expect(live.groups[0].delay == .none)
    }

    @Test func liveArrivalsElsewhereAreIgnored() {
        var live = plan(.journalSquare)
        live.apply(realtime: [Fixture.arrival(.newport, "33rd Street", at: Fixture.date("2026-11-24 07:12"))], now: now)
        #expect(live.board(at: now).lines[0].text == "33rd 7:10 :20 :30 :40 :50")
    }

    @Test func aLiveTrainTakesTheRoutingOfItsScheduledTwin() throws {
        let night = Fixture.date("2026-11-24 23:05")
        var live = plan(.journalSquare, targets: [.thirtyThirdStreet], at: night)
        live.apply(realtime: [Fixture.arrival(.journalSquare, "33rd Street", at: Fixture.date("2026-11-24 23:21"))], now: night)
        let train = try #require(live.groups[0].trains.first)
        #expect(train.isLive)
        // Via Hoboken takes 32 minutes, not the direct 23.
        #expect(schedule.arrival(of: train, from: .journalSquare, to: .thirtyThirdStreet) == train.time.addingTimeInterval(32 * 60))
    }

    // MARK: Alerts

    private func issue(_ kind: IssueKind, lines: [String], ended: Bool = false, detected: Bool = false) -> PathSchedule.Issue {
        PathSchedule.Issue(id: UUID().uuidString, kind: kind, title: "Test", updates: [], startedAt: now,
              endedAt: ended ? now : nil, affectedLines: lines, detected: detected)
    }

    @Test func anAlertNamingALineMarksThatLineOnly() {
        var board = plan(.journalSquare)
        board.apply(issues: [issue(.delay, lines: ["JSQ-33"])], includePlannedWork: true)
        let lines = board.board(at: now).lines
        #expect(lines[0].text.hasPrefix("33rd! "))
        #expect(lines[1].text.hasPrefix("WTC "))
        #expect(!board.board(at: now).hasAlert)
    }

    @Test func alertsWithoutALineShowTheHeaderMark() {
        var general = plan(.journalSquare)
        general.apply(issues: [issue(.other, lines: [])], includePlannedWork: false)
        #expect(general.board(at: now).hasAlert)

        var planned = plan(.journalSquare)
        planned.apply(issues: [issue(.plannedWork, lines: [])], includePlannedWork: false)
        #expect(!planned.board(at: now).hasAlert)
        planned.apply(issues: [issue(.plannedWork, lines: [])], includePlannedWork: true)
        #expect(planned.board(at: now).hasAlert)
    }

    @Test func elevatorAndEndedIssuesNeverShow() {
        var board = plan(.journalSquare)
        board.apply(issues: [issue(.elevator, lines: []), issue(.delay, lines: ["JSQ-33"], ended: true), issue(.delay, lines: ["JSQ-33"], detected: true)],
                    includePlannedWork: true)
        let result = board.board(at: now)
        #expect(!result.hasAlert)
        #expect(result.lines.allSatisfy { $0.delay == .none })
    }

    @Test func anAlertForAnotherLineLeavesThisStationAlone() {
        var board = plan(.ninthStreet)
        board.apply(issues: [issue(.suspension, lines: ["NWK-WTC"])], includePlannedWork: true)
        #expect(board.board(at: now).lines.allSatisfy { $0.delay == .none })
    }
}

@Suite("Head signs")
struct HeadSignTests {
    @Test(arguments: [
        ("World Trade Center", Station.journalSquare, Station.worldTradeCenter, true),
        ("World Trade Center", .journalSquare, .thirtyThirdStreet, false),
        ("33rd Street", .journalSquare, .thirtyThirdStreet, true),
        ("33rd Street", .journalSquare, .hoboken, false),
        ("33rd Street via Hoboken", .journalSquare, .hoboken, true),
        ("33rd Street via Hoboken", .journalSquare, .thirtyThirdStreet, true),
        ("Journal Square via Hoboken", .thirtyThirdStreet, .hoboken, true),
        ("Journal Square", .thirtyThirdStreet, .hoboken, false),
        ("Hoboken", .thirtyThirdStreet, .hoboken, true),
        ("Hoboken", .worldTradeCenter, .newport, true),
        ("Newark", .worldTradeCenter, .journalSquare, true),
        ("Newark", .journalSquare, .worldTradeCenter, false),
        ("Mystery Express", .journalSquare, .worldTradeCenter, false),
    ])
    func headSignsSayWhereATrainStops(sign: String, origin: Station, target: Station, serves: Bool) {
        #expect(RealtimeFeed.serves(headSign: sign, from: origin, to: target) == serves)
    }
}
