import Foundation
import Testing
@testable import PathGlance

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

    @Test func nameLengthCoversTheLabelAndItsDelayMark() {
        let line = BoardLine(label: "33rd", times: [], delay: .none)
        #expect(line.nameLength == 4)
        let late = BoardLine(label: "33rd", times: [], delay: .minor)
        #expect(late.nameLength == ("33rd" + DelayLevel.minor.marker).count)
        #expect(late.text.hasPrefix(String(late.text.prefix(late.nameLength))))
        // The second line of one destination is times only: nothing to make heavier.
        #expect(BoardLine(label: "", times: []).nameLength == 0)
    }

    @Test func hiddenDestinationsLeaveTheWidget() {
        #expect(BoardRules.widgetTargets(from: .journalSquare, hidden: [.worldTradeCenter]) == [.thirtyThirdStreet])
        // A station whose only line is turned off still shows it.
        #expect(BoardRules.widgetTargets(from: .newark, hidden: [.worldTradeCenter]) == [.worldTradeCenter])
        #expect(BoardRules.widgetTargets(from: .journalSquare, hidden: []) == [.thirtyThirdStreet, .worldTradeCenter])
    }

    @Test func destinationTabsListEveryReachableLineEnd() {
        let tabs = BoardRules.destinations(from: .journalSquare, hidden: [], schedule: Fixture.schedule)
        // Hoboken is only passed through from Journal Square, so it is not a tab.
        #expect(tabs == [.thirtyThirdStreet, .worldTradeCenter, .newark])
        let fewer = BoardRules.destinations(from: .journalSquare, hidden: [.worldTradeCenter], schedule: Fixture.schedule)
        #expect(fewer == [.thirtyThirdStreet, .newark])
        #expect(BoardRules.destinations(from: .thirtyThirdStreet, hidden: [], schedule: Fixture.schedule) == [.journalSquare, .hoboken])
        #expect(Fixture.schedule.terminals(from: .journalSquare) == [.thirtyThirdStreet, .worldTradeCenter, .newark])
        #expect(Fixture.schedule.terminals(from: .newport) == [.thirtyThirdStreet, .journalSquare, .hoboken, .worldTradeCenter])
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

    @Test func skippingTheNextTrainStartsEachLineFromItsSecond() {
        var style = WidgetStyle(timeFormat: .short)
        style.skipNext = true
        let board = plan(.journalSquare, style: style).board(at: now)
        #expect(board.lines.map(\.text) == ["33rd 7:20 :30 :40 :50 8:00", "WTC 7:13 :23 :33 :43 :53"])
    }

    @Test func theLastTrainIsNeverSkipped() {
        var only = plan(.journalSquare, targets: [.thirtyThirdStreet])
        only.style.skipNext = true
        only.groups[0].trains = Array(only.groups[0].trains.prefix(1))
        #expect(only.board(at: now).lines.first?.times.count == 1)
    }

    @Test func amAndPmFollowTheFirstTimeAndAChangeOfPeriod() {
        var style = WidgetStyle(density: .regular, timeFormat: .full, showArrival: true)
        style.showsPeriod = true
        #expect(plan(.journalSquare, style: style).board(at: now).lines.first?.text == "33rd 7:10→7:33 AM, 7:20, 7:30")
        let late = [Fixture.date("2026-11-24 11:50"), Fixture.date("2026-11-24 12:05"), Fixture.date("2026-11-24 12:20")]
        #expect(CompactTimes.string(late, format: .full, showsPeriod: true) == "11:50 AM, 12:05 PM, 12:20")
        #expect(CompactTimes.string(late, format: .short, showsPeriod: true) == "11:50 AM 12:05 PM :20")
        #expect(CompactTimes.string(late, format: .full) == "11:50, 12:05, 12:20", "Off by default")
    }

    @Test func compressingDropsTheSpaceAfterCommas() {
        var style = WidgetStyle(density: .compact, timeFormat: .full)
        style.compress = true
        let line = plan(.journalSquare, style: style).board(at: now).lines.first
        #expect(line?.text == "33rd 7:10,7:20,7:30,7:40")
        #expect(line?.compress == true)
    }

    @Test func theNewOptionsAreOffAndTheStationRowOnByDefault() {
        let style = WidgetStyle()
        #expect(!style.skipNext && !style.showsPeriod && !style.compress && style.showsHeader)
        #expect(WidgetPreset.builtIn.allSatisfy { $0.look.style.showsHeader && !$0.look.style.skipNext })
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

    private func issue(_ kind: IssueKind, lines: [String], ended: Bool = false, detected: Bool = false) -> PathGlance.Issue {
        PathGlance.Issue(id: UUID().uuidString, kind: kind, title: "Test", updates: [], startedAt: now,
              endedAt: ended ? now : nil, affectedLines: lines, detected: detected)
    }

    @Test func anAlertNamingALineMarksThatLineOnly() {
        var board = plan(.journalSquare)
        board.apply(issues: [issue(.delay, lines: ["JSQ-33"])], muted: [])
        let lines = board.board(at: now).lines
        #expect(lines[0].text.hasPrefix("33rd! "))
        #expect(lines[1].text.hasPrefix("WTC "))
        #expect(!board.board(at: now).hasAlert)
    }

    @Test func alertsWithoutALineShowTheHeaderMark() {
        var general = plan(.journalSquare)
        general.apply(issues: [issue(.other, lines: [])], muted: [.plannedWork])
        #expect(general.board(at: now).hasAlert)

        var planned = plan(.journalSquare)
        planned.apply(issues: [issue(.plannedWork, lines: [])], muted: [.plannedWork])
        #expect(!planned.board(at: now).hasAlert)
        planned.apply(issues: [issue(.plannedWork, lines: [])], muted: [])
        #expect(planned.board(at: now).hasAlert)
    }

    @Test func mutedAndEndedIssuesNeverShow() {
        var board = plan(.journalSquare)
        board.apply(issues: [issue(.elevator, lines: []), issue(.delay, lines: ["JSQ-33"], ended: true), issue(.delay, lines: ["JSQ-33"], detected: true)],
                    muted: SharedStore.defaultMutedKinds)
        let result = board.board(at: now)
        #expect(!result.hasAlert)
        #expect(result.lines.allSatisfy { $0.delay == .none })
    }

    @Test func anAlertForAnotherLineLeavesThisStationAlone() {
        var board = plan(.ninthStreet)
        board.apply(issues: [issue(.suspension, lines: ["NWK-WTC"])], muted: [])
        #expect(board.board(at: now).lines.allSatisfy { $0.delay == .none })
    }

    @Test func mutingAKindKeepsItOffTheWidget() {
        var board = plan(.journalSquare)
        board.apply(issues: [issue(.suspension, lines: ["JSQ-33"]), issue(.other, lines: [])], muted: [.suspension, .other])
        let result = board.board(at: now)
        #expect(!result.hasAlert)
        #expect(result.lines.allSatisfy { $0.delay == .none })
    }

    @Test func mutingDelaysAlsoClearsLiveDelayMarks() {
        let saturday = Fixture.date("2026-11-28 07:15")
        var live = plan(.journalSquare, at: saturday)
        live.apply(realtime: [Fixture.arrival(.journalSquare, "33rd Street", at: Fixture.date("2026-11-28 07:35"))], now: saturday)
        #expect(live.groups[0].delay == .major)
        live.apply(issues: [], muted: [.delay])
        #expect(live.board(at: saturday).lines.allSatisfy { $0.delay == .none })
    }

    // MARK: Fitting times on a line

    @Test func twoDestinationsTryNoMoreThanTheCap() {
        let board = plan(.journalSquare).board(at: now)
        #expect(board.counts(cap: 3) == [3, 2, 1])
        #expect(board.counts(cap: 99) == [8, 7, 6, 5, 4, 3, 2, 1])
        #expect(board.lines(perLine: 2).map(\.text) == ["33rd 7:10 :20", "WTC 7:03 :13"])
    }

    @Test func oneDestinationFillsBothRowsWhateverTheCap() {
        let board = plan(.journalSquare, targets: [.thirtyThirdStreet]).board(at: now)
        #expect(board.counts(cap: 2) == [8, 7, 6, 5, 4, 3, 2, 1])
        #expect(board.lines(perLine: 3).map(\.text) == ["33rd 7:10 :20 :30", "7:40 :50 8:00"])
    }

    // MARK: Late trains

    @Test func aLiveTrainKnowsTheTimetableTimeItReplaces() throws {
        let saturday = Fixture.date("2026-11-28 07:15")
        var live = plan(.journalSquare, at: saturday)
        live.apply(realtime: [Fixture.arrival(.journalSquare, "33rd Street", at: Fixture.date("2026-11-28 07:30"))], now: saturday)
        let train = try #require(live.groups[0].trains.first)
        #expect(train.scheduled == Fixture.date("2026-11-28 07:23"))
        #expect(train.delayMinutes == 7)
        #expect(train.isLate)
    }

    @Test func aTrainOnTimeIsNotLate() throws {
        var live = plan(.journalSquare)
        live.apply(realtime: [Fixture.arrival(.journalSquare, "33rd Street", at: Fixture.date("2026-11-24 07:11"))], now: now)
        let train = try #require(live.groups[0].trains.first)
        #expect(train.delayMinutes == 1)
        #expect(!train.isLate)
        // A timetable train is never late by itself.
        #expect(live.groups[0].trains[1].delayMinutes == 0)
    }

    @Test func delaysAreWrittenShort() {
        #expect(TrainTime.delayText(3) == "+3m")
        #expect(TrainTime.delayText(62) == "+1h2m")
    }
}

@Suite("Widget looks")
struct WidgetLookTests {
    @Test func theDefaultLookIsTheDefaultPreset() {
        #expect(WidgetPreset.matching(WidgetLook())?.id == "default")
        #expect(Set(WidgetPreset.builtIn.map(\.id)).count == WidgetPreset.builtIn.count)
        #expect(Set(WidgetPreset.builtIn.map(\.look)).count == WidgetPreset.builtIn.count, "Two presets must not look the same")
    }

    @Test func anEditedPresetMatchesNothing() {
        var look = WidgetPreset.builtIn[2].look
        #expect(WidgetPreset.matching(look) != nil)
        look.style.showArrival.toggle()
        #expect(WidgetPreset.matching(look) == nil)
    }

    @Test func aLookSurvivesSavingAndLoading() throws {
        let look = WidgetLook(font: .serif, style: WidgetStyle(density: .regular, timeFormat: .short, showArrival: true, maxTimes: 4))
        let loaded = try JSONDecoder().decode(WidgetLook.self, from: JSONEncoder().encode(look))
        #expect(loaded == look)
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
