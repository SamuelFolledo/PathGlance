import Foundation

/// The rows of one destination's train list: a block per day, a week back to two weeks
/// ahead. Building it is pure work on values, so it runs off the main thread, and every
/// day but today is cached (`TrainListCache`).
struct TrainList: Sendable {
    struct Row: Identifiable, Sendable {
        enum Kind: Sendable {
            /// `cells` are the arrival times for each of the list's columns; `nil` where
            /// this train does not call.
            case train(TrainTime, cells: [Date?])
            /// The routing changes here, for example to "J Sq via Hob".
            case routeChange(String)
        }

        /// Seconds since 1970, so rows sort and compare as times. A divider sits just
        /// before the train it introduces.
        var id: Double
        var kind: Kind
        /// Already gone: drawn dimmed.
        var isPast = false

        var train: TrainTime? {
            if case .train(let train, _) = kind { return train }
            return nil
        }
    }

    struct Day: Identifiable, Sendable {
        /// `yyyymmdd`
        var id: Int
        var date: Date
        var title: String
        var isToday = false
        /// A holiday or learned-timetable warning.
        var note: String?
        var rows: [Row]

        /// The id of the day's heading row in the list, just before its first train.
        var headerID: Double { date.timeIntervalSince1970 - 1 }
    }

    /// What a list is built from. Two lists with equal keys have the same rows on every
    /// day but today, which is what makes caching by it safe.
    struct Key: Hashable, Sendable {
        var origin: Station
        var target: Station
        var favorites: [Station]
        var imported: Date
        var overrides: [Int: Int]
        /// `yyyymmdd` of today: past rows are dimmed relative to it.
        var today: Int
    }

    /// Favourite stops trains to this destination call at on the way, in travel order,
    /// then the destination itself.
    var columns: [Station] = []
    var days: [Day] = []
    /// How late the next train is running, today only.
    var delay: DelayLevel = .none
    var delayMinutes = 0
    /// Changes whenever the rows do, so views can skip redrawing an unchanged list.
    var version = UUID()

    /// Every train in the list, in order.
    var trains: [TrainTime] { days.flatMap { $0.rows.compactMap(\.train) } }

    // MARK: Building

    /// Everything needed to turn the timetable into rows for one origin and destination.
    struct Builder: Sendable {
        let schedule: ScheduleData
        let origin: Station
        let target: Station
        let columns: [Station]
        let dayTypes: DayTypeLog
        let now: Date

        private var today: Date { PathTime.calendar.startOfDay(for: now) }

        init(schedule base: ScheduleData, origin: Station, target: Station, favorites: [Station], dayTypes: DayTypeLog, now: Date) {
            var schedule = base
            for date in Builder.dates(around: now) {
                schedule.dayOverrides.merge(dayTypes.overrides(around: date)) { current, _ in current }
            }
            self.schedule = schedule
            self.origin = origin
            self.target = target
            self.dayTypes = dayTypes
            self.now = now
            self.columns = TrainList.columns(schedule: schedule, origin: origin, target: target, favorites: favorites)
        }

        static func dates(around now: Date) -> [Date] {
            let today = PathTime.calendar.startOfDay(for: now)
            return (-AppModel.daysBack...AppModel.daysAhead).compactMap { PathTime.calendar.date(byAdding: .day, value: $0, to: today) }
        }

        var key: Key {
            Key(origin: origin, target: target, favorites: columns, imported: schedule.importedAt,
                overrides: schedule.dayOverrides, today: PathTime.ymd(of: now))
        }

        /// One day's rows. `live` replaces today's upcoming trains with live times.
        func day(_ date: Date, live: BoardPlan.Group? = nil) -> Day {
            let ymd = PathTime.ymd(of: date)
            let isToday = date == today
            let cutoff = now.addingTimeInterval(-BoardPlan.grace)
            var trains = schedule.departures(from: origin, to: target, after: date.addingTimeInterval(-1), limit: 1000)
                .filter { PathTime.ymd(of: $0.time) == ymd }
            if isToday, let live {
                trains = trains.filter { $0.time <= cutoff } + live.trains.filter { PathTime.ymd(of: $0.time) == ymd }
            }

            // Routing and ride times depend only on which stops a train makes: once per pattern.
            var patterns: [Int: (via: Bool, name: String, rides: [Station: Int])] = [:]
            func pattern(_ train: TrainTime) -> (via: Bool, name: String, rides: [Station: Int]) {
                if let known = patterns[train.downstream] { return known }
                let value = (schedule.runsViaHoboken(train, from: origin), schedule.routeName(of: train, from: origin),
                             schedule.rideTable(from: origin, downstream: train.downstream))
                patterns[train.downstream] = value
                return value
            }

            var rows: [Row] = []
            rows.reserveCapacity(trains.count + 2)
            var previousVia: Bool?
            for train in trains {
                let info = pattern(train)
                if let previousVia, previousVia != info.via {
                    rows.append(Row(id: train.time.timeIntervalSince1970 - 0.5, kind: .routeChange(info.name)))
                }
                previousVia = info.via
                let toTarget = info.rides[target]
                let cells: [Date?] = columns.map { stop in
                    guard let minutes = info.rides[stop] else { return nil }
                    // A favourite the train only reaches after the destination is not on the way.
                    if stop != target, let toTarget, minutes >= toTarget { return nil }
                    return train.time.addingTimeInterval(TimeInterval(minutes * 60))
                }
                rows.append(Row(id: train.time.timeIntervalSince1970, kind: .train(train, cells: cells),
                                isPast: !train.isLive && train.time <= cutoff))
            }

            let offset = PathTime.calendar.dateComponents([.day], from: today, to: date).day ?? 0
            let name: String
            switch offset {
            case 0: name = "Today · "
            case 1: name = "Tomorrow · "
            case -1: name = "Yesterday · "
            default: name = ""
            }
            return Day(id: ymd, date: date, title: name + PathFormat.day(date), isToday: isToday,
                       note: dayTypes.resolution(forYMD: ymd)?.note, rows: rows)
        }

        /// The whole list. `cached` supplies days already built for the same `key`.
        func list(arrivals: [RealtimeArrival], issues: [Issue], cached: [Int: Day] = [:]) -> TrainList {
            var list = TrainList()
            list.columns = columns

            var plan = BoardPlan(station: origin, targets: [target], schedule: schedule, now: now, limit: 600)
            plan.apply(realtime: arrivals, now: now)
            plan.apply(issues: issues, includePlannedWork: false)
            let live = plan.groups.first
            list.delay = live?.delay ?? .none
            list.delayMinutes = live?.delayMinutes ?? 0

            for date in Builder.dates(around: now) {
                if date == today {
                    list.days.append(day(date, live: live))
                } else {
                    list.days.append(cached[PathTime.ymd(of: date)] ?? day(date))
                }
            }
            return list
        }
    }

    /// Builds the list without a cache. Used by tests and anywhere a one-off is enough.
    static func build(schedule: ScheduleData, origin: Station, target: Station, favorites: [Station],
                      arrivals: [RealtimeArrival], issues: [Issue], dayTypes: DayTypeLog, now: Date) -> TrainList {
        Builder(schedule: schedule, origin: origin, target: target, favorites: favorites, dayTypes: dayTypes, now: now)
            .list(arrivals: arrivals, issues: issues)
    }

    /// A favourite gets a column when some train from `origin` calls there before reaching `target`.
    static func columns(schedule: ScheduleData, origin: Station, target: Station, favorites: [Station]) -> [Station] {
        let patterns = Set((schedule.departures[origin.rawValue] ?? []).map(\.downstream).filter { $0 & target.bit != 0 })
        var onTheWay: [(station: Station, minutes: Int)] = []
        for stop in favorites where stop != origin && stop != target {
            let rides = patterns.compactMap { pattern -> Int? in
                guard pattern & stop.bit != 0,
                      let toStop = schedule.rideMinutes(from: origin, to: stop, downstream: pattern),
                      let toTarget = schedule.rideMinutes(from: origin, to: target, downstream: pattern),
                      toStop < toTarget else { return nil }
                return toStop
            }
            if let shortest = rides.min() {
                onTheWay.append((stop, shortest))
            }
        }
        return onTheWay.sorted { $0.minutes < $1.minutes }.map(\.station) + [target]
    }

    // MARK: Finding rows

    /// The row to put at the top of the list to show the first train at or after `time`.
    func rowID(for time: Date) -> Double? {
        let stamp = time.timeIntervalSince1970
        for day in days {
            if let row = day.rows.first(where: { $0.id >= stamp }) { return row.id }
        }
        return days.last?.rows.last?.id
    }

    /// The day a row id falls on.
    func day(containing id: Double?) -> Day? {
        guard let id else { return days.first }
        return days.last { $0.headerID <= id } ?? days.first
    }

    /// The time a row id stands for.
    static func time(of id: Double) -> Date {
        Date(timeIntervalSince1970: id)
    }
}

/// Days already built, by what they were built from. Switching destination, station or
/// day and coming back reuses them instead of working the timetable out again.
@MainActor
final class TrainListCache {
    private var days: [TrainList.Key: [Int: TrainList.Day]] = [:]
    /// Keys in the order they were last used, oldest first.
    private var recent: [TrainList.Key] = []
    private let limit = 24

    /// The list for these inputs. Only today, and any day not seen before, is worked out,
    /// and that happens off the main thread.
    func list(schedule: ScheduleData, origin: Station, target: Station, favorites: [Station],
              arrivals: [RealtimeArrival], issues: [Issue], dayTypes: DayTypeLog, now: Date) async -> TrainList {
        let cached = days
        let (list, key) = await Task.detached(priority: .userInitiated) {
            let builder = TrainList.Builder(schedule: schedule, origin: origin, target: target, favorites: favorites, dayTypes: dayTypes, now: now)
            return (builder.list(arrivals: arrivals, issues: issues, cached: cached[builder.key] ?? [:]), builder.key)
        }.value

        var stored: [Int: TrainList.Day] = [:]
        for day in list.days where !day.isToday { stored[day.id] = day }
        days[key] = stored
        recent.removeAll { $0 == key }
        recent.append(key)
        while recent.count > limit {
            days[recent.removeFirst()] = nil
        }
        return list
    }

    func removeAll() {
        days = [:]
        recent = []
    }
}
