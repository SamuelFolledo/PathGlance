import Foundation

/// The three timetables PATH publishes. Raw values are the indexes into `ScheduleData.services`.
enum DayType: Int, Codable, CaseIterable, Sendable {
    case weekday, saturday, sunday

    var name: String {
        switch self {
        case .weekday: return "Weekday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    /// The timetable a date gets from the calendar alone.
    static func normal(forYMD ymd: Int) -> DayType {
        guard let date = PathTime.date(fromYMD: ymd) else { return .weekday }
        switch PathTime.calendar.component(.weekday, from: date) {
        case 1: return .sunday
        case 7: return .saturday
        default: return .weekday
        }
    }
}

/// Days on which PATH may not run the timetable the calendar suggests.
enum Holiday: String, Codable, CaseIterable, Sendable {
    case newYearsDay, mlkDay, presidentsDay, memorialDay, juneteenth, independenceDay, laborDay
    case thanksgiving, dayAfterThanksgiving, christmasEve, christmas, newYearsEve

    var name: String {
        switch self {
        case .newYearsDay: return "New Year's Day"
        case .mlkDay: return "Martin Luther King Jr. Day"
        case .presidentsDay: return "Presidents' Day"
        case .memorialDay: return "Memorial Day"
        case .juneteenth: return "Juneteenth"
        case .independenceDay: return "Independence Day"
        case .laborDay: return "Labor Day"
        case .thanksgiving: return "Thanksgiving"
        case .dayAfterThanksgiving: return "Day after Thanksgiving"
        case .christmasEve: return "Christmas Eve"
        case .christmas: return "Christmas"
        case .newYearsEve: return "New Year's Eve"
        }
    }

    func ymd(in year: Int) -> Int {
        func fixed(_ month: Int, _ day: Int) -> Int { year * 10_000 + month * 100 + day }
        /// The `ordinal`th `weekday` of `month` (Calendar weekday numbers; -1 for the last).
        func nth(_ ordinal: Int, _ weekday: Int, _ month: Int) -> Int {
            var parts = DateComponents(year: year, month: month, weekday: weekday, weekdayOrdinal: ordinal)
            parts.timeZone = PathTime.calendar.timeZone
            guard let date = PathTime.calendar.date(from: parts) else { return fixed(month, 1) }
            return PathTime.ymd(of: date)
        }
        switch self {
        case .newYearsDay: return fixed(1, 1)
        case .mlkDay: return nth(3, 2, 1)
        case .presidentsDay: return nth(3, 2, 2)
        case .memorialDay: return nth(-1, 2, 5)
        case .juneteenth: return fixed(6, 19)
        case .independenceDay: return fixed(7, 4)
        case .laborDay: return nth(1, 2, 9)
        case .thanksgiving: return nth(4, 5, 11)
        case .dayAfterThanksgiving:
            let thanksgiving = PathTime.date(fromYMD: nth(4, 5, 11)) ?? Date()
            return PathTime.ymd(of: PathTime.calendar.date(byAdding: .day, value: 1, to: thanksgiving) ?? thanksgiving)
        case .christmasEve: return fixed(12, 24)
        case .christmas: return fixed(12, 25)
        case .newYearsEve: return fixed(12, 31)
        }
    }

    static func on(ymd: Int) -> Holiday? {
        allCases.first { $0.ymd(in: ymd / 10_000) == ymd }
    }
}

/// How well one day's live arrivals matched each of the three timetables.
struct DayObservation: Codable, Hashable, Sendable {
    var ymd: Int
    var samples = 0
    /// Summed gap in minutes between each live arrival and the nearest scheduled train,
    /// per `DayType`. The gap is capped so one stray prediction cannot swing the result.
    var errorSum: [Double] = [0, 0, 0]

    func meanError(_ type: DayType) -> Double {
        samples == 0 ? 0 : errorSum[type.rawValue] / Double(samples)
    }

    /// The timetable PATH evidently ran, once there is enough evidence to say.
    var matched: DayType? {
        guard samples >= DayTypeLog.minimumSamples else { return nil }
        let normal = DayType.normal(forYMD: ymd)
        guard let best = DayType.allCases.min(by: { meanError($0) < meanError($1) }) else { return nil }
        // Only leave the calendar's answer when another timetable fits clearly better.
        if best != normal, meanError(best) <= 2.5, meanError(normal) - meanError(best) >= 1.5 {
            return best
        }
        return normal
    }
}

/// Which timetable to use on a date and why, for the dates where that is not obvious.
struct DayResolution: Sendable {
    enum Source: Sendable {
        /// Today's live arrivals match this timetable.
        case observed
        /// No data for the date yet; this is what ran on the same holiday in `year`.
        case earlierYear(Int)
        /// A holiday with nothing to go on.
        case unknownHoliday
    }

    var type: DayType
    var source: Source
    var holiday: Holiday?

    /// Shown as a warning beside the day in the app. `nil` when there is nothing to flag.
    var note: String? {
        let label = holiday?.name ?? "Today"
        switch source {
        case .observed:
            return "\(label): live trains match the \(type.name) timetable"
        case .earlierYear(let year):
            return "\(label): using \(year)'s timetable (\(type.name)) until live data is in"
        case .unknownHoliday:
            return "\(label): holiday timetable not known yet, showing \(type.name)"
        }
    }
}

/// What the app has learned about which timetable PATH runs on which dates.
struct DayTypeLog: Codable, Sendable {
    static let fileName = "daytypes.json"
    static let minimumSamples = 40
    private static let gapCap = 10.0

    /// Keyed by `yyyymmdd`.
    var days: [String: DayObservation] = [:]

    static func load() -> DayTypeLog {
        SharedStore.read(DayTypeLog.self, from: fileName) ?? DayTypeLog()
    }

    func save() {
        SharedStore.write(self, to: DayTypeLog.fileName)
    }

    var observations: [DayObservation] {
        days.values.sorted { $0.ymd > $1.ymd }
    }

    /// Scores the current live arrivals against each timetable.
    mutating func record(arrivals: [RealtimeArrival], schedule: ScheduleData, now: Date) {
        guard schedule.services.count == DayType.allCases.count else { return }
        let ymd = PathTime.ymd(of: now)
        var day = days[String(ymd)] ?? DayObservation(ymd: ymd)
        let midnight = PathTime.calendar.startOfDay(for: now)

        for arrival in arrivals {
            let minute = Int(arrival.arrival.timeIntervalSince(midnight) / 60)
            // Overnight the three timetables are nearly the same and trains from the
            // previous service day are still running, so those hours say little.
            guard minute >= 5 * 60, minute < 24 * 60 else { continue }
            var targets = 0
            for target in Station.allCases where target != arrival.station
                && RealtimeFeed.serves(headSign: arrival.headSign, from: arrival.station, to: target) {
                targets |= target.bit
            }
            guard targets != 0, let list = schedule.departures[arrival.station.rawValue] else { continue }

            var gaps = Array(repeating: DayTypeLog.gapCap, count: DayType.allCases.count)
            for departure in list where departure.downstream & targets != 0 && gaps.indices.contains(departure.service) {
                gaps[departure.service] = min(gaps[departure.service], Double(abs(departure.minute - minute)))
            }
            day.samples += 1
            for index in gaps.indices { day.errorSum[index] += gaps[index] }
        }
        days[String(ymd)] = day

        // Two years is enough to carry every holiday forward.
        let oldest = (ymd / 10_000 - 2) * 10_000
        days = days.filter { $0.value.ymd >= oldest }
    }

    /// `nil` when the date simply runs the calendar's timetable.
    func resolution(forYMD ymd: Int) -> DayResolution? {
        let normal = DayType.normal(forYMD: ymd)
        let holiday = Holiday.on(ymd: ymd)
        if let matched = days[String(ymd)]?.matched {
            if matched != normal {
                return DayResolution(type: matched, source: .observed, holiday: holiday)
            }
            return nil
        }
        guard let holiday else { return nil }
        for yearsBack in 1...2 {
            let year = ymd / 10_000 - yearsBack
            if let earlier = days[String(holiday.ymd(in: year))]?.matched {
                return DayResolution(type: earlier, source: .earlierYear(year), holiday: holiday)
            }
        }
        return DayResolution(type: normal, source: .unknownHoliday, holiday: holiday)
    }

    /// Timetable overrides for the days around `date`, in the form `ScheduleData` takes.
    func overrides(around date: Date) -> [Int: Int] {
        var result: [Int: Int] = [:]
        for offset in -1...2 {
            guard let day = PathTime.calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            let ymd = PathTime.ymd(of: day)
            if let resolution = resolution(forYMD: ymd), resolution.type != DayType.normal(forYMD: ymd) {
                result[ymd] = resolution.type.rawValue
            }
        }
        return result
    }
}
