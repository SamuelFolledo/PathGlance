import Foundation
import Testing
@testable import PathGlance

@Suite("Timetable import")
struct ImporterTests {
    let schedule = Fixture.schedule

    @Test func readsEveryStationAndTheEffectiveDate() {
        #expect(schedule.feedVersion == "Effective November 16, 2026")
        #expect(schedule.services.count == 3)
        for station in Station.allCases {
            #expect(!(schedule.departures[station.rawValue] ?? []).isEmpty, "no departures from \(station.name)")
        }
        #expect(!schedule.isExpired(on: Fixture.date("2030-01-01 12:00")))
    }

    @Test func clockTimesBecomeMinutes() {
        #expect(WebTimetableImporter.minutes(fromClock: "12:00 AM") == 0)
        #expect(WebTimetableImporter.minutes(fromClock: "5:49 AM") == 349)
        #expect(WebTimetableImporter.minutes(fromClock: "12:30 PM") == 750)
        #expect(WebTimetableImporter.minutes(fromClock: "11:59 PM") == 1439)
        #expect(WebTimetableImporter.minutes(fromClock: "---") == nil)
        #expect(WebTimetableImporter.minutes(fromClock: "13:00 PM") == nil)
    }

    @Test func columnHeadersMapToStations() {
        let expected: [String: Station] = [
            "JSQ Departure": .journalSquare, "Grove St Departure": .groveStreet, "Newport Departure": .newport,
            "Chris St Departure": .christopherStreet, "9 St Departure": .ninthStreet, "14 St Departure": .fourteenthStreet,
            "23 St Departure": .twentyThirdStreet, "Arrival at 33 St": .thirtyThirdStreet, "Exchange Departure": .exchangePlace,
            "Arrival at WTC": .worldTradeCenter, "Newark Departure": .newark, "Harrison Departure": .harrison,
            "Hoboken Departure": .hoboken,
        ]
        for (header, station) in expected {
            #expect(WebTimetableImporter.station(forHeader: header) == station, "\(header)")
        }
        #expect(WebTimetableImporter.station(forHeader: "Secaucus Departure") == nil)
    }

    @Test func aTrainPastMidnightKeepsCounting() {
        // The 11:40 PM via-Hoboken train reaches Christopher Street at 12:05 AM: minute 1445 of its day.
        let late = (schedule.departures[Station.christopherStreet.rawValue] ?? []).filter { $0.service == 0 && $0.minute == 23 * 60 + 40 + 25 }
        #expect(!late.isEmpty)
    }

    @Test func aStopTheTrainSkipsHasNoDeparture() {
        // Weekday overnight trains pass 9th Street: nothing leaves 9th for 33rd at 12:26 AM.
        let trains = schedule.departures(from: .ninthStreet, to: .thirtyThirdStreet, after: Fixture.date("2026-11-24 00:10"), limit: 3)
        #expect(Fixture.clocks(trains).first == "6:15")
        // The same train still serves 14th Street.
        let fourteenth = schedule.departures(from: .fourteenthStreet, to: .thirtyThirdStreet, after: Fixture.date("2026-11-24 00:10"), limit: 1)
        #expect(Fixture.clocks(fourteenth) == ["12:28"])
    }

    @Test func rideTimesFollowTheRouting() throws {
        let direct = try #require(schedule.departures(from: .journalSquare, to: .thirtyThirdStreet, after: Fixture.date("2026-11-24 07:00"), limit: 1).first)
        let via = try #require(schedule.departures(from: .journalSquare, to: .thirtyThirdStreet, after: Fixture.date("2026-11-24 23:00"), limit: 1).first)
        #expect(schedule.arrival(of: direct, from: .journalSquare, to: .thirtyThirdStreet) == direct.time.addingTimeInterval(23 * 60))
        #expect(schedule.arrival(of: via, from: .journalSquare, to: .thirtyThirdStreet) == via.time.addingTimeInterval(32 * 60))
        #expect(!schedule.runsViaHoboken(direct, from: .journalSquare))
        #expect(schedule.runsViaHoboken(via, from: .journalSquare))
        #expect(schedule.routeName(of: direct, from: .journalSquare) == "33rd")
        #expect(schedule.routeName(of: via, from: .journalSquare) == "33rd via Hob")
    }

    @Test func stopsAreListedInTravelOrder() throws {
        let via = try #require(schedule.departures(from: .journalSquare, to: .thirtyThirdStreet, after: Fixture.date("2026-11-28 23:00"), limit: 1).first)
        let stops = schedule.stops(of: via, from: .journalSquare)
        #expect(stops.map(\.station) == [.groveStreet, .newport, .hoboken, .christopherStreet, .ninthStreet, .fourteenthStreet, .twentyThirdStreet, .thirtyThirdStreet])
        #expect(CompactTimes.clock(via.time) == "11:03")
        #expect(stops.map { CompactTimes.clock($0.time) } == ["11:07", "11:11", "11:19", "11:28", "11:29", "11:31", "11:32", "11:35"])
    }

    @Test func aPageThatChangedShapeIsRejected() {
        #expect(throws: WebTimetableError.self) {
            try WebTimetableImporter.build(pageModel: Data("{\"other\": 1}".utf8))
        }
        let unknownStation = String(decoding: Fixture.pageModel(), as: UTF8.self).replacingOccurrences(of: "Harrison", with: "Secaucus")
        #expect(throws: WebTimetableError.self) {
            try WebTimetableImporter.build(pageModel: Data(unknownStation.utf8))
        }
    }
}

@Suite("Schedule queries")
struct ScheduleTests {
    let schedule = Fixture.schedule

    @Test func eachDayTypeRunsItsOwnTimetable() {
        func next(_ day: String) -> [String] {
            Fixture.clocks(schedule.departures(from: .journalSquare, to: .thirtyThirdStreet, after: Fixture.date("\(day) 07:01"), limit: 3))
        }
        #expect(next("2026-11-24") == ["7:10", "7:20", "7:30"]) // Tuesday
        #expect(next("2026-11-28") == ["7:03", "7:23", "7:43"]) // Saturday
        #expect(next("2026-11-29") == ["7:07", "7:37", "8:07"]) // Sunday
    }

    @Test func aTargetOnlySomeTrainsReachFiltersTheList() {
        // From Journal Square, Hoboken is only on the overnight routing.
        let trains = schedule.departures(from: .journalSquare, to: .hoboken, after: Fixture.date("2026-11-24 12:00"), limit: 2)
        #expect(Fixture.clocks(trains) == ["11:00", "11:20"])
        #expect(schedule.reaches(from: .journalSquare, to: .hoboken))
        #expect(!schedule.reaches(from: .journalSquare, to: .newark) == false)
        #expect(!schedule.reaches(from: .thirtyThirdStreet, to: .worldTradeCenter))
    }

    @Test func lateTrainsFromYesterdayShowAfterMidnight() {
        // Monday's 11:40 PM from Journal Square calls at Christopher Street at 12:05 AM on Tuesday.
        let trains = schedule.departures(from: .christopherStreet, to: .thirtyThirdStreet, after: Fixture.date("2026-11-24 00:01"), limit: 1)
        #expect(Fixture.clocks(trains) == ["12:05"])
    }

    @Test func aDayOverrideSwapsTheTimetable() {
        var holiday = schedule
        holiday.dayOverrides = [20261126: DayType.sunday.rawValue] // Thanksgiving, a Thursday
        let normal = schedule.departures(from: .journalSquare, to: .thirtyThirdStreet, after: Fixture.date("2026-11-26 07:01"), limit: 2)
        let sunday = holiday.departures(from: .journalSquare, to: .thirtyThirdStreet, after: Fixture.date("2026-11-26 07:01"), limit: 2)
        #expect(Fixture.clocks(normal) == ["7:10", "7:20"])
        #expect(Fixture.clocks(sunday) == ["7:07", "7:37"])
    }

    @Test func limitAndOrderAreRespected() {
        let trains = schedule.departures(from: .groveStreet, to: .journalSquare, after: Fixture.date("2026-11-24 08:00"), limit: 12)
        #expect(trains.count == 12)
        #expect(trains.map(\.time) == trains.map(\.time).sorted())
        #expect(Set(trains.map(\.time)).count == 12)
    }

    @Test func scheduleSurvivesSavingAndLoading() throws {
        let data = try JSONEncoder().encode(schedule)
        let loaded = try JSONDecoder().decode(ScheduleData.self, from: data)
        #expect(loaded.departures.count == schedule.departures.count)
        #expect(loaded.travel == schedule.travel)
        #expect(loaded.dayOverrides.isEmpty)
    }
}

@Suite("Stations")
struct StationTests {
    @Test func nearestStationByCoordinates() {
        #expect(Station.nearest(latitude: 40.7332, longitude: -74.0628) == .journalSquare)
        #expect(Station.nearest(latitude: 40.7491, longitude: -73.9883) == .thirtyThirdStreet)
        #expect(Station.nearest(latitude: 40.7116, longitude: -74.0113) == .worldTradeCenter)
    }

    @Test func everyStationHasItsOwnBit() {
        #expect(Set(Station.allCases.map(\.bit)).count == Station.allCases.count)
    }

    @Test func widgetLinksRoundTrip() {
        let url = AppLink.line(from: .journalSquare, to: .thirtyThirdStreet)
        let parsed = AppLink.parseLine(url)
        #expect(parsed?.origin == .journalSquare)
        #expect(parsed?.target == .thirtyThirdStreet)
        #expect(AppLink.parseLine(URL(string: "https://example.com/line?from=newark&to=harrison")!) == nil)
        #expect(AppLink.parseLine(URL(string: "pathglance://line?from=nowhere&to=harrison")!) == nil)
    }
}
