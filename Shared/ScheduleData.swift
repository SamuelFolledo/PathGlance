import Foundation

enum PathTime {
    /// PATH runs on New York time regardless of the phone's time zone.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return calendar
    }()

    /// `yyyymmdd` in New York time.
    static func ymd(of date: Date) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }

    /// Midnight in New York at the start of a `yyyymmdd` day.
    static func date(fromYMD ymd: Int) -> Date? {
        calendar.date(from: DateComponents(year: ymd / 10_000, month: ymd / 100 % 100, day: ymd % 100))
    }
}

/// One scheduled departure from a station. Encoded as `[minute, service, downstream]`
/// to keep the shared file small.
struct Departure: Codable, Sendable {
    /// Minutes after the service day's midnight. Can exceed 1440 for trips after midnight.
    var minute: Int
    /// Index into `ScheduleData.services`.
    var service: Int
    /// Bitmask of the stations this trip reaches after this stop (see `Station.bit`).
    var downstream: Int

    init(minute: Int, service: Int, downstream: Int) {
        self.minute = minute
        self.service = service
        self.downstream = downstream
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        minute = try container.decode(Int.self)
        service = try container.decode(Int.self)
        downstream = try container.decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(minute)
        try container.encode(service)
        try container.encode(downstream)
    }
}

/// A GTFS service (calendar.txt plus calendar_dates.txt). Dates are `yyyymmdd` integers.
struct ServiceCalendar: Codable, Sendable {
    /// Monday through Sunday.
    var weekdays: [Bool] = Array(repeating: false, count: 7)
    var start: Int = 0
    var end: Int = 0
    var added: [Int] = []
    var removed: [Int] = []

    /// `ignoringEnd` keeps the weekly pattern running after `end`, for a feed that has
    /// expired without a replacement being published.
    func isActive(on day: Int, weekdayIndex: Int, ignoringEnd: Bool = false) -> Bool {
        if removed.contains(day) { return false }
        if added.contains(day) { return true }
        guard day >= start, day <= end || ignoringEnd, weekdays.indices.contains(weekdayIndex) else { return false }
        return weekdays[weekdayIndex]
    }
}

/// A departure resolved to a real date.
struct TrainTime: Hashable, Sendable {
    var time: Date
    /// Stations the train reaches after this stop (see `Station.bit`).
    var downstream: Int
    /// A live prediction, not a timetable time.
    var isLive = false

    func serves(_ station: Station) -> Bool {
        downstream & station.bit != 0
    }
}

struct ScheduleData: Codable, Sendable {
    var importedAt: Date
    var feedVersion: String?
    /// Last service date covered by the feed (`yyyymmdd`), when the feed states one.
    var feedEnd: Int?
    var services: [ServiceCalendar]
    /// Keyed by `Station.rawValue`, sorted by `minute`.
    var departures: [String: [Departure]]
    /// Dates (`yyyymmdd`) that run a different service than the calendar says, such as a
    /// holiday on the Sunday timetable. Values index `services`. Filled in after loading
    /// from what `DayTypeLog` has learned; not part of the stored file.
    var dayOverrides: [Int: Int] = [:]

    init(importedAt: Date, feedVersion: String?, feedEnd: Int?, services: [ServiceCalendar],
         departures: [String: [Departure]], travel: [String: Int]? = nil) {
        self.importedAt = importedAt
        self.feedVersion = feedVersion
        self.feedEnd = feedEnd
        self.services = services
        self.departures = departures
        self.travel = travel
    }

    /// Typical ride time in minutes, keyed by `travelKey`. Missing in files saved by older builds.
    var travel: [String: Int]?

    private enum CodingKeys: String, CodingKey {
        case importedAt, feedVersion, feedEnd, services, departures, travel
    }

    /// `downstream` pins the routing (direct or via Hoboken); `nil` is the general figure.
    static func travelKey(from origin: Station, to target: Station, downstream: Int?) -> String {
        "\(origin.rawValue)>\(target.rawValue)" + (downstream.map { ">\($0)" } ?? "")
    }

    /// When `train`, boarded at `origin`, is due at `target`.
    func arrival(of train: TrainTime, from origin: Station, to target: Station) -> Date? {
        guard let travel else { return nil }
        let minutes = travel[ScheduleData.travelKey(from: origin, to: target, downstream: train.downstream)]
            ?? travel[ScheduleData.travelKey(from: origin, to: target, downstream: nil)]
        return minutes.map { train.time.addingTimeInterval(TimeInterval($0 * 60)) }
    }

    /// Typical minutes from `origin` to `stop` for a train with this routing.
    func rideMinutes(from origin: Station, to stop: Station, downstream: Int) -> Int? {
        guard let travel else { return nil }
        return travel[ScheduleData.travelKey(from: origin, to: stop, downstream: downstream)]
            ?? travel[ScheduleData.travelKey(from: origin, to: stop, downstream: nil)]
    }

    /// Every stop `train` makes after `origin`, in order, with its arrival time there.
    func stops(of train: TrainTime, from origin: Station) -> [(station: Station, time: Date)] {
        Station.allCases
            .filter { train.serves($0) && $0 != origin }
            .compactMap { stop -> (station: Station, time: Date)? in
                guard let minutes = rideMinutes(from: origin, to: stop, downstream: train.downstream) else { return nil }
                return (stop, train.time.addingTimeInterval(TimeInterval(minutes * 60)))
            }
            .sorted { $0.time < $1.time }
    }

    /// Where `train` ends its run.
    func terminal(of train: TrainTime, from origin: Station) -> Station? {
        stops(of: train, from: origin).last?.station
    }

    /// True for the Journal Square to 33rd Street trains that detour through Hoboken:
    /// the train calls at Hoboken and carries on.
    func runsViaHoboken(_ train: TrainTime, from origin: Station) -> Bool {
        guard origin != .hoboken, train.serves(.hoboken), let terminal = terminal(of: train, from: origin) else { return false }
        return terminal != .hoboken
    }

    /// "J Sq via Hob", "J Sq", "Hoboken": where the train is going, for list dividers.
    func routeName(of train: TrainTime, from origin: Station) -> String {
        guard let terminal = terminal(of: train, from: origin) else { return "" }
        return runsViaHoboken(train, from: origin) ? "\(terminal.shortName) via Hob" : terminal.shortName
    }

    /// Whether any train from `origin` later stops at `target`.
    func reaches(from origin: Station, to target: Station) -> Bool {
        origin != target && (departures[origin.rawValue] ?? []).contains { $0.downstream & target.bit != 0 }
    }

    /// Upcoming departures from `origin` on trips that later stop at `target`.
    func departures(from origin: Station, to target: Station, after date: Date, limit: Int) -> [TrainTime] {
        guard let list = departures[origin.rawValue], !list.isEmpty else { return [] }
        let calendar = PathTime.calendar
        let today = calendar.startOfDay(for: date)
        var results: [TrainTime] = []

        // Yesterday's service day covers trips after midnight; tomorrow fills the list late at night.
        for offset in -1...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: day)
            guard let year = parts.year, let month = parts.month, let dayOfMonth = parts.day,
                  let weekday = parts.weekday else { continue }
            let ymd = year * 10_000 + month * 100 + dayOfMonth
            let weekdayIndex = (weekday + 5) % 7 // Calendar: Sunday = 1. GTFS order: Monday first.

            var active = Set<Int>()
            // PATH has left its published feed in place past its end date before, so an
            // expired feed keeps its regular weekly timetable rather than going blank.
            let expired = feedEnd.map { ymd > $0 } ?? false
            for index in services.indices
            where services[index].isActive(on: ymd, weekdayIndex: weekdayIndex, ignoringEnd: expired) {
                active.insert(index)
            }
            if let override = dayOverrides[ymd], services.indices.contains(override) {
                active = [override]
            }
            if active.isEmpty { continue }

            for departure in list where departure.downstream & target.bit != 0 && active.contains(departure.service) {
                let when = day.addingTimeInterval(TimeInterval(departure.minute * 60))
                if when > date { results.append(TrainTime(time: when, downstream: departure.downstream)) }
            }
        }

        results.sort { $0.time < $1.time }
        var unique: [TrainTime] = []
        for train in results where unique.last?.time != train.time {
            unique.append(train)
            if unique.count == limit { break }
        }
        return unique
    }

    /// True when the feed's stated end date has passed.
    func isExpired(on date: Date = Date()) -> Bool {
        guard let feedEnd else { return false }
        let parts = PathTime.calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return false }
        return year * 10_000 + month * 100 + day > feedEnd
    }
}
