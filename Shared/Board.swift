import Foundation

/// One line on the lock screen, for example "33rd 7:10 :30 :50 8:00 :10".
/// How far a line is running behind the timetable.
enum DelayLevel: Int, Comparable, Sendable {
    case none, minor, major

    /// Shown after the line label: "33rd?" for a small delay, "33rd!" for a big one.
    var marker: String {
        switch self {
        case .none: return ""
        case .minor: return "?"
        case .major: return "!"
        }
    }

    static func < (lhs: DelayLevel, rhs: DelayLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct BoardLine: Hashable, Sendable {
    /// Empty for the second line when one destination fills both lines.
    var label: String
    var times: [Date]
    var delay: DelayLevel = .none
    /// The destination this line lists, for opening its full list in the app.
    var target: Station?
    /// When the first train reaches `target`, if the widget is set to show it.
    var arrival: Date?

    /// "7:16 :30 :50", or "7:16→:35 :30 :50" with the first train's arrival time.
    var timesText: String { CompactTimes.string(times, arrivalOfFirst: arrival) }

    /// "33rd? 7:16 :30 :50 8:00 :10"
    var text: String {
        label.isEmpty ? timesText : "\(label)\(delay.marker) \(timesText)"
    }
}

struct Board: Hashable, Sendable {
    var station: Station
    /// Zero, one or two lines.
    var lines: [BoardLine]
    /// An open PATH alert that is not tied to one of the lines shown.
    var hasAlert = false
}

enum BoardRules {
    /// Which destinations to show from each station.
    static func targets(from station: Station) -> [Station] {
        switch station {
        case .journalSquare:
            return [.thirtyThirdStreet, .worldTradeCenter]
        case .groveStreet, .newport, .christopherStreet, .ninthStreet, .fourteenthStreet, .twentyThirdStreet:
            return [.thirtyThirdStreet, .journalSquare]
        case .thirtyThirdStreet:
            return [.journalSquare, .hoboken]
        case .worldTradeCenter:
            return [.newark]
        case .hoboken:
            return [.thirtyThirdStreet, .worldTradeCenter]
        case .exchangePlace:
            return [.worldTradeCenter, .journalSquare]
        case .newark, .harrison:
            return [.worldTradeCenter]
        }
    }
}

extension BoardRules {
    /// The widget's lines: the user's favourite destinations that trains from `station`
    /// reach, topped up from the station's rules. With no favourites it is the rules alone.
    static func widgetTargets(from station: Station, favorites: [Station], schedule: ScheduleData) -> [Station] {
        let rules = targets(from: station)
        var result = Array(favorites.filter { schedule.reaches(from: station, to: $0) }.prefix(2))
        guard !result.isEmpty else { return rules }
        for target in rules where result.count < 2 && !result.contains(target) {
            result.append(target)
        }
        return result
    }
}

enum CompactTimes {
    /// "7:05" in New York time, 12-hour, no AM/PM.
    static func clock(_ date: Date) -> String {
        let parts = PathTime.calendar.dateComponents([.hour, .minute], from: date)
        return "\(hour12(parts.hour ?? 0)):\(twoDigits(parts.minute ?? 0))"
    }

    /// "7:05 AM" in New York time.
    static func clockWithPeriod(_ date: Date) -> String {
        let hour = PathTime.calendar.component(.hour, from: date)
        return "\(clock(date)) \(hour < 12 ? "AM" : "PM")"
    }

    /// "7:10 :30 :50 8:00 :10". The hour is dropped when it repeats.
    static func string(_ times: [Date], arrivalOfFirst: Date? = nil) -> String {
        var parts: [String] = []
        var lastHour: Int?
        func short(_ time: Date) -> String {
            let components = PathTime.calendar.dateComponents([.hour, .minute], from: time)
            let hour = hour12(components.hour ?? 0)
            let minute = twoDigits(components.minute ?? 0)
            defer { lastHour = hour }
            return hour == lastHour ? ":\(minute)" : "\(hour):\(minute)"
        }
        for (index, time) in times.enumerated() {
            var part = short(time)
            if index == 0, let arrivalOfFirst {
                part += "→" + short(arrivalOfFirst)
            }
            parts.append(part)
        }
        return parts.joined(separator: " ")
    }

    private static func hour12(_ hour: Int) -> Int {
        let h = hour % 12
        return h == 0 ? 12 : h
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

/// Departure lists for one station over the next few hours. Built once per widget
/// reload, then sliced into a `Board` for each timeline entry.
struct BoardPlan: Sendable {
    struct Group: Sendable {
        var target: Station
        var trains: [TrainTime]
        /// Timetable times from shortly before now onwards, kept to measure delays against.
        var timetable: [Date] = []
        var delay: DelayLevel = .none
        /// Minutes the next live train is behind the timetable.
        var delayMinutes = 0
    }

    /// A train stays on the board for this long after its departure time.
    static let grace: TimeInterval = 60
    /// PATH says trains may run three minutes either side of the timetable; flag beyond that.
    static let minorDelay = 5
    static let majorDelay = 10

    let station: Station
    var groups: [Group]
    var hasAlert = false
    /// Put the first train's arrival time at its destination on each line.
    var showArrival = false
    private let schedule: ScheduleData

    /// `targets` defaults to the station's board rules.
    init(station: Station, targets: [Station]? = nil, schedule: ScheduleData, now: Date, limit: Int = 60) {
        self.station = station
        self.schedule = schedule
        self.groups = (targets ?? BoardRules.targets(from: station)).map { target in
            let all = schedule.departures(from: station, to: target, after: now.addingTimeInterval(-30 * 60), limit: limit + 40)
            let visibleFrom = now.addingTimeInterval(-BoardPlan.grace)
            return Group(
                target: target,
                trains: Array(all.filter { $0.time > visibleFrom }.prefix(limit)),
                timetable: all.map(\.time)
            )
        }
    }

    /// Replaces the earliest scheduled times with live predictions where the feed has them.
    mutating func apply(realtime arrivals: [RealtimeArrival], now: Date) {
        let targets = groups.map(\.target)
        let here = arrivals.filter { $0.station == station && $0.arrival > now.addingTimeInterval(-30) }
        for index in groups.indices {
            let target = groups[index].target
            let live: [TrainTime] = here
                .filter { RealtimeFeed.serves(headSign: $0.headSign, from: station, to: target) }
                .map { arrival in
                    var downstream = 0
                    for other in targets where RealtimeFeed.serves(headSign: arrival.headSign, from: station, to: other) {
                        downstream |= other.bit
                    }
                    // The feed has no stop list, so borrow the routing (direct or via
                    // Hoboken) of the scheduled train this prediction is closest to.
                    let nearest = groups[index].trains.min {
                        abs($0.time.timeIntervalSince(arrival.arrival)) < abs($1.time.timeIntervalSince(arrival.arrival))
                    }
                    if let nearest, abs(nearest.time.timeIntervalSince(arrival.arrival)) <= 15 * 60 {
                        downstream |= nearest.downstream
                    }
                    return TrainTime(time: arrival.arrival, downstream: downstream, isLive: true)
                }
                .sorted { $0.time < $1.time }
            guard let firstLive = live.first, let lastLive = live.last else { continue }

            // The next live train is the latest scheduled one it could be: trains rarely
            // run more than three minutes early. On a frequent line a long delay looks
            // like the following train on time, which is why PATH's alerts count as well.
            if let scheduled = groups[index].timetable.last(where: { $0 <= firstLive.time.addingTimeInterval(3 * 60) }) {
                let minutes = Int(firstLive.time.timeIntervalSince(scheduled) / 60)
                // A gap of half an hour or more is a break in service, not a late train.
                if minutes >= BoardPlan.minorDelay, minutes < 30 {
                    groups[index].delayMinutes = minutes
                    groups[index].delay = minutes >= BoardPlan.majorDelay ? .major : .minor
                }
            }

            // Scheduled trains close to the last live prediction are the same trains.
            let cutoff = lastLive.time.addingTimeInterval(4 * 60)
            groups[index].trains = live + groups[index].trains.filter { $0.time > cutoff }
        }
    }

    /// Marks the lines PATH's open alerts name, and notes any alert that names none.
    mutating func apply(issues: [Issue], includePlannedWork: Bool) {
        for issue in issues where issue.isActive && !issue.detected && issue.kind != .elevator {
            if issue.affectedLines.isEmpty {
                if issue.kind != .plannedWork || includePlannedWork { hasAlert = true }
                continue
            }
            for index in groups.indices where issue.affects(from: station, to: groups[index].target) {
                groups[index].delay = .major
            }
        }
    }

    func board(at date: Date, perLine: Int = 5) -> Board {
        let visibleFrom = date.addingTimeInterval(-BoardPlan.grace)
        let upcoming = groups
            .map { group -> Group in
                var copy = group
                copy.trains = group.trains.filter { $0.time > visibleFrom }
                return copy
            }
            .filter { !$0.trains.isEmpty }

        guard let first = upcoming.first else {
            return Board(station: station, lines: [], hasAlert: hasAlert)
        }

        if upcoming.count >= 2 {
            let second = upcoming[1]
            let a = Array(first.trains.prefix(perLine))
            let b = Array(second.trains.prefix(perLine))
            // The same trains serve both destinations (for example Journal Square via Hoboken
            // late at night), so list them once across both lines.
            let sameTrains = a.map(\.time) == b.map(\.time)
                && a.allSatisfy { $0.serves(second.target) }
                && b.allSatisfy { $0.serves(first.target) }
            if sameTrains {
                var both = first
                both.delay = max(first.delay, second.delay)
                return Board(station: station, lines: filled(label: "All", group: both, perLine: perLine), hasAlert: hasAlert)
            }
            return Board(station: station, lines: [
                BoardLine(label: first.target.lineLabel, times: a.map(\.time), delay: first.delay, target: first.target, arrival: arrival(in: first)),
                BoardLine(label: second.target.lineLabel, times: b.map(\.time), delay: second.delay, target: second.target, arrival: arrival(in: second)),
            ], hasAlert: hasAlert)
        }

        return Board(station: station, lines: filled(label: first.target.lineLabel, group: first, perLine: perLine), hasAlert: hasAlert)
    }

    private func arrival(in group: Group) -> Date? {
        guard showArrival, let train = group.trains.first else { return nil }
        return schedule.arrival(of: train, from: station, to: group.target)
    }

    private func filled(label: String, group: Group, perLine: Int) -> [BoardLine] {
        let times = group.trains.map(\.time)
        let firstLine = Array(times.prefix(perLine))
        let secondLine = Array(times.dropFirst(perLine).prefix(perLine))
        var lines = [BoardLine(label: label, times: firstLine, delay: group.delay, target: group.target, arrival: arrival(in: group))]
        if !secondLine.isEmpty {
            lines.append(BoardLine(label: "", times: secondLine, target: group.target))
        }
        return lines
    }

    /// Moments at which the board changes: now, then one minute after each departure.
    func refreshDates(from now: Date, horizon: TimeInterval = 2 * 60 * 60, maxCount: Int = 40) -> [Date] {
        var moments = Set<Date>()
        for group in groups {
            for train in group.trains {
                let moment = train.time.addingTimeInterval(BoardPlan.grace)
                if moment > now && moment <= now.addingTimeInterval(horizon) {
                    moments.insert(moment)
                }
            }
        }
        return [now] + moments.sorted().prefix(maxCount)
    }
}
