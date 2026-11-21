import Foundation

enum PathTime {
    /// PATH runs on New York time regardless of the phone's time zone.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return calendar
    }()
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

    func isActive(on day: Int, weekdayIndex: Int) -> Bool {
        if removed.contains(day) { return false }
        if added.contains(day) { return true }
        guard day >= start, day <= end, weekdays.indices.contains(weekdayIndex) else { return false }
        return weekdays[weekdayIndex]
    }
}

/// A departure resolved to a real date.
struct TrainTime: Hashable, Sendable {
    var time: Date
    /// Stations the train reaches after this stop (see `Station.bit`).
    var downstream: Int

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
            for index in services.indices where services[index].isActive(on: ymd, weekdayIndex: weekdayIndex) {
                active.insert(index)
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
