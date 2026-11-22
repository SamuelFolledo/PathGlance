import Foundation

/// The rows of one destination's train list: a section per day, a week back to two
/// weeks ahead, built once per change so scrolling does no work.
struct TrainList {
    struct Row: Identifiable {
        enum Kind {
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
        var isPast = false
    }

    struct Day: Identifiable {
        /// `yyyymmdd`
        var id: Int
        var date: Date
        var title: String
        /// A holiday or learned-timetable warning.
        var note: String?
        var rows: [Row]

        /// The id of the day's heading row in the list, just before its first train.
        var headerID: Double { date.timeIntervalSince1970 - 1 }
    }

    /// Favourite stops trains to this destination call at on the way, in travel order,
    /// then the destination itself.
    var columns: [Station] = []
    var days: [Day] = []
    /// How late the next train is running, today only.
    var delay: DelayLevel = .none
    var delayMinutes = 0

    static func build(schedule base: ScheduleData, origin: Station, target: Station, favorites: [Station],
                      arrivals: [RealtimeArrival], issues: [Issue], dayTypes: DayTypeLog, now: Date,
                      daysBack: Int = AppModel.daysBack, daysAhead: Int = AppModel.daysAhead) -> TrainList {
        let calendar = PathTime.calendar
        let today = calendar.startOfDay(for: now)
        let dates = (-daysBack...daysAhead).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }

        var schedule = base
        for date in dates {
            schedule.dayOverrides.merge(dayTypes.overrides(around: date)) { current, _ in current }
        }

        var list = TrainList()
        list.columns = columns(schedule: schedule, origin: origin, target: target, favorites: favorites)

        // Routing only depends on which stops a train makes, so work it out once per pattern.
        var routes: [Int: (viaHoboken: Bool, name: String)] = [:]
        func route(_ train: TrainTime) -> (viaHoboken: Bool, name: String) {
            if let known = routes[train.downstream] { return known }
            let value = (schedule.runsViaHoboken(train, from: origin), schedule.routeName(of: train, from: origin))
            routes[train.downstream] = value
            return value
        }

        for date in dates {
            let ymd = PathTime.ymd(of: date)
            let isToday = date == today
            var trains = schedule.departures(from: origin, to: target, after: date.addingTimeInterval(-1), limit: 1000)
                .filter { PathTime.ymd(of: $0.time) == ymd }

            if isToday {
                // Trains still to come take live times; earlier ones stay as scheduled.
                var plan = BoardPlan(station: origin, targets: [target], schedule: schedule, now: now, limit: 600)
                plan.apply(realtime: arrivals, now: now)
                plan.apply(issues: issues, includePlannedWork: false)
                if let group = plan.groups.first {
                    let cutoff = now.addingTimeInterval(-BoardPlan.grace)
                    trains = trains.filter { $0.time <= cutoff } + group.trains.filter { PathTime.ymd(of: $0.time) == ymd }
                    list.delay = group.delay
                    list.delayMinutes = group.delayMinutes
                }
            }

            var rows: [Row] = []
            var previousVia: Bool?
            for train in trains {
                let via = route(train).viaHoboken
                if let previousVia, previousVia != via {
                    rows.append(Row(id: train.time.timeIntervalSince1970 - 0.5, kind: .routeChange(route(train).name)))
                }
                previousVia = via
                let targetArrival = schedule.arrival(of: train, from: origin, to: target)
                let cells: [Date?] = list.columns.map { stop in
                    guard train.serves(stop), let arrival = schedule.arrival(of: train, from: origin, to: stop) else { return nil }
                    // A favourite the train only reaches after the destination is not on the way.
                    if stop != target, let targetArrival, arrival >= targetArrival { return nil }
                    return arrival
                }
                rows.append(Row(id: train.time.timeIntervalSince1970, kind: .train(train, cells: cells),
                                isPast: isToday && !train.isLive && train.time <= now.addingTimeInterval(-BoardPlan.grace)))
            }

            let offset = calendar.dateComponents([.day], from: today, to: date).day ?? 0
            let name: String
            switch offset {
            case 0: name = "Today · "
            case 1: name = "Tomorrow · "
            case -1: name = "Yesterday · "
            default: name = ""
            }
            list.days.append(Day(id: ymd, date: date, title: name + PathFormat.day(date),
                                 note: dayTypes.resolution(forYMD: ymd)?.note, rows: rows))
        }
        return list
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

    private var allRows: [(id: Double, dayIndex: Int, rowIndex: Int)] {
        days.enumerated().flatMap { dayIndex, day in
            day.rows.enumerated().map { (id: $0.element.id, dayIndex: dayIndex, rowIndex: $0.offset) }
        }
    }

    /// The row to put at the top of the list to show the first train at or after `time`.
    func rowID(for time: Date) -> Double? {
        let stamp = time.timeIntervalSince1970
        return allRows.first { $0.id >= stamp }?.id ?? allRows.last?.id
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
