import Foundation
import Testing
@testable import PathSchedule

@Suite("Train list")
struct TrainListTests {
    let schedule = Fixture.schedule
    let now = Fixture.date("2026-11-24 07:01")

    private func list(_ origin: Station, _ target: Station, favorites: [Station] = [], arrivals: [RealtimeArrival] = [],
                      at date: Date? = nil, dayTypes: DayTypeLog = DayTypeLog()) -> TrainList {
        TrainList.build(schedule: schedule, origin: origin, target: target, favorites: favorites, arrivals: arrivals,
                        issues: [], dayTypes: dayTypes, now: date ?? now)
    }

    private func trains(_ day: TrainList.Day) -> [(train: TrainTime, cells: [Date?])] {
        day.rows.compactMap { row in
            if case .train(let train, let cells) = row.kind { return (train, cells) }
            return nil
        }
    }

    @Test func coversAWeekBackAndTwoWeeksAhead() {
        let built = list(.journalSquare, .thirtyThirdStreet)
        #expect(built.days.count == 22)
        #expect(built.days.first?.id == 20261117)
        #expect(built.days.last?.id == 20261208)
        #expect(built.days[7].title.hasPrefix("Today · "))
        #expect(built.days[8].title.hasPrefix("Tomorrow · "))
        #expect(built.days[6].title.hasPrefix("Yesterday · "))
    }

    @Test func withNoFavoritesTheOnlyColumnIsTheDestination() {
        #expect(list(.journalSquare, .thirtyThirdStreet).columns == [.thirtyThirdStreet])
    }

    @Test func favoritesOnTheWayBecomeColumnsInTravelOrder() {
        let favorites: [Station] = [.thirtyThirdStreet, .christopherStreet, .newport, .journalSquare, .exchangePlace]
        // From 33rd to Journal Square: Christopher Street then Newport, then the destination.
        // 33rd is where we are, and no Journal Square train calls at Exchange Place.
        #expect(list(.thirtyThirdStreet, .journalSquare, favorites: favorites).columns == [.christopherStreet, .newport, .journalSquare])
        // Hoboken to the World Trade Center does pass Exchange Place.
        #expect(list(.hoboken, .worldTradeCenter, favorites: favorites).columns == [.newport, .exchangePlace, .worldTradeCenter])
        // A favorite beyond the destination is not on the way.
        #expect(list(.journalSquare, .newport, favorites: [.christopherStreet]).columns == [.newport])
    }

    @Test func cellsHoldEachStopsArrivalTime() throws {
        let built = list(.journalSquare, .thirtyThirdStreet, favorites: [.newport, .christopherStreet])
        let today = built.days[7]
        let train = try #require(trains(today).first { $0.train.time == Fixture.date("2026-11-24 07:10") })
        #expect(train.cells == [Fixture.date("2026-11-24 07:18"), Fixture.date("2026-11-24 07:26"), Fixture.date("2026-11-24 07:33")])
    }

    @Test func arrivalTimesChangeWhenTheTrainGoesViaHoboken() throws {
        let built = list(.journalSquare, .thirtyThirdStreet, favorites: [.christopherStreet])
        let today = trains(built.days[7])
        let direct = try #require(today.first { $0.train.time == Fixture.date("2026-11-24 22:50") })
        let via = try #require(today.first { $0.train.time == Fixture.date("2026-11-24 23:00") })
        #expect(direct.cells == [Fixture.date("2026-11-24 23:06"), Fixture.date("2026-11-24 23:13")])
        #expect(via.cells == [Fixture.date("2026-11-24 23:25"), Fixture.date("2026-11-24 23:32")])
    }

    @Test func aStopTheTrainSkipsShowsNoTime() throws {
        // Weekday overnight trains pass 9th Street.
        let built = list(.journalSquare, .thirtyThirdStreet, favorites: [.ninthStreet])
        let via = try #require(trains(built.days[7]).first { $0.train.time == Fixture.date("2026-11-24 23:00") })
        #expect(via.cells.first == .some(nil))
        #expect(via.cells.last == .some(Fixture.date("2026-11-24 23:32")))
    }

    @Test func aDividerMarksWhereTheRoutingChanges() {
        let built = list(.journalSquare, .thirtyThirdStreet)
        let labels = built.days[7].rows.compactMap { row -> String? in
            if case .routeChange(let name) = row.kind { return name }
            return nil
        }
        // Via Hoboken until 5:40 AM, direct through the day, via Hoboken again from 11 PM.
        #expect(labels == ["33rd", "33rd via Hob"])
        // The same switch shows when the list is for Hoboken from 33rd Street.
        let hoboken = list(.thirtyThirdStreet, .hoboken)
        let hobokenLabels = hoboken.days[7].rows.compactMap { row -> String? in
            if case .routeChange(let name) = row.kind { return name }
            return nil
        }
        #expect(hobokenLabels == ["Hoboken", "J Sq via Hob"])
    }

    @Test func todaySplitsIntoPastAndUpcomingWithLiveTimes() throws {
        let live = [Fixture.arrival(.journalSquare, "33rd Street", at: Fixture.date("2026-11-24 07:12"))]
        let built = list(.journalSquare, .thirtyThirdStreet, arrivals: live)
        let today = built.days[7]
        let past = today.rows.filter(\.isPast)
        #expect(!past.isEmpty)
        let upcoming = trains(TrainList.Day(id: 0, date: now, title: "", rows: today.rows.filter { !$0.isPast }))
        #expect(upcoming.first?.train.time == Fixture.date("2026-11-24 07:12"))
        #expect(upcoming.first?.train.isLive == true)
        #expect(upcoming.dropFirst().first?.train.time == Fixture.date("2026-11-24 07:20"))
        // Other days have no past rows.
        #expect(built.days[8].rows.allSatisfy { !$0.isPast })
    }

    @Test func rowsAreInTimeOrderWithUniqueIDs() {
        let built = list(.groveStreet, .journalSquare)
        let ids = built.days.flatMap { [$0.headerID] + $0.rows.map(\.id) }
        #expect(ids == ids.sorted())
        #expect(Set(ids).count == ids.count)
    }

    @Test func findingTheRowForATime() throws {
        let built = list(.journalSquare, .thirtyThirdStreet)
        let id = try #require(built.rowID(for: Fixture.date("2026-11-24 07:01")))
        #expect(TrainList.time(of: id) == Fixture.date("2026-11-24 07:10"))
        #expect(built.day(containing: id)?.id == 20261124)
        // Past the end of the list lands on the last row.
        let last = try #require(built.rowID(for: Fixture.date("2027-01-01 00:00")))
        #expect(built.day(containing: last)?.id == 20261208)
        // A day's heading belongs to that day.
        #expect(built.day(containing: built.days[9].headerID)?.id == built.days[9].id)
    }

    @Test func aLearnedHolidayChangesThatDaysTrainsAndFlagsIt() {
        var log = DayTypeLog()
        log.days["20251127"] = DayObservation(ymd: 20251127, samples: 200, errorSum: [900, 700, 150])
        let built = list(.journalSquare, .thirtyThirdStreet, dayTypes: log)
        let thanksgiving = built.days.first { $0.id == 20261126 }
        #expect(thanksgiving?.note == "Thanksgiving: using 2025's timetable (Sunday) until live data is in")
        // Sunday service: every 30 minutes through the day.
        let morning = trains(thanksgiving!).map(\.train.time).filter { $0 >= Fixture.date("2026-11-26 07:00") }.prefix(3)
        #expect(Array(morning) == ["2026-11-26 07:07", "2026-11-26 07:37", "2026-11-26 08:07"].map(Fixture.date))
        #expect(built.days.first { $0.id == 20261125 }?.note == nil)
    }
}
