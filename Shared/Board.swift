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
    var timeFormat: WidgetTimeFormat = .full

    /// "7:16, 7:30, 7:50" or "7:16 :30 :50". With the first train's arrival time:
    /// "7:16→7:35, 7:30".
    var timesText: String { CompactTimes.string(times, arrivalOfFirst: arrival, format: timeFormat) }

    /// "33rd? 7:16 :30 :50 8:00 :10"
    var text: String {
        label.isEmpty ? timesText : "\(label)\(delay.marker) \(timesText)"
    }
}

/// One destination's upcoming trains, before they are cut to what fits on a line.
struct BoardRow: Hashable, Sendable {
    var label: String
    var target: Station
    var delay: DelayLevel = .none
    /// More than a line holds, so the widget can show as many as fit.
    var times: [Date]
    var arrival: Date?
    var timeFormat: WidgetTimeFormat = .full
}

struct Board: Hashable, Sendable {
    /// The most times a line is ever given.
    static let mostPerLine = 8

    var station: Station
    /// Zero, one or two destinations.
    var rows: [BoardRow]
    /// How many times a line shows when nothing measures what fits.
    var perLine = 5
    /// An open PATH alert that is not tied to one of the lines shown.
    var hasAlert = false

    /// The lines at the usual number of times each.
    var lines: [BoardLine] { lines(perLine: perLine) }

    /// The lines with `count` times each. Two destinations get a line each. One
    /// destination runs on across both lines, the second without a label.
    func lines(perLine count: Int) -> [BoardLine] {
        if rows.count == 1, let row = rows.first {
            let first = Array(row.times.prefix(count))
            let second = Array(row.times.dropFirst(count).prefix(count))
            var lines = [BoardLine(label: row.label, times: first, delay: row.delay, target: row.target, arrival: row.arrival, timeFormat: row.timeFormat)]
            if !second.isEmpty {
                lines.append(BoardLine(label: "", times: second, target: row.target, timeFormat: row.timeFormat))
            }
            return lines
        }
        return rows.map { row in
            BoardLine(label: row.label, times: Array(row.times.prefix(count)), delay: row.delay, target: row.target,
                      arrival: row.arrival, timeFormat: row.timeFormat)
        }
    }

    /// The numbers of times per line worth trying, most first. Two destinations stop at
    /// the user's cap. One destination ignores it: the space is there to be filled.
    func counts(cap: Int) -> [Int] {
        let most = rows.count == 1 ? Board.mostPerLine : min(max(cap, 1), Board.mostPerLine)
        return Array((1...most).reversed())
    }
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
    /// The ends of the lines, which is what a destination tab or widget line can be.
    static let terminals: [Station] = [.thirtyThirdStreet, .worldTradeCenter, .journalSquare, .hoboken, .newark]

    /// The widget's lines: the station's rules without the destinations the user has
    /// turned off. If that would leave nothing, the rules stand.
    static func widgetTargets(from station: Station, hidden: Set<Station>) -> [Station] {
        let rules = targets(from: station)
        let kept = rules.filter { !hidden.contains($0) }
        return kept.isEmpty ? rules : kept
    }

    /// The destination tabs in the app: the widget's lines, then the other stations where
    /// trains from `station` end, without the ones turned off. Hoboken is not a tab at
    /// Journal Square: trains only pass through it there.
    static func destinations(from station: Station, hidden: Set<Station>, schedule: ScheduleData) -> [Station] {
        var result = widgetTargets(from: station, hidden: hidden)
        let ends = schedule.terminals(from: station)
        for terminal in terminals where !result.contains(terminal) && !hidden.contains(terminal) && ends.contains(terminal) {
            result.append(terminal)
        }
        return result
    }
}

/// How the widget writes its times.
enum WidgetTimeFormat: String, CaseIterable, Identifiable, Sendable {
    /// "10:16, 10:35, 10:55"
    case full
    /// "10:16 :35 :55"
    case short

    var id: String { rawValue }
    var name: String { self == .full ? "Full" : "Shortened" }
    var example: String { self == .full ? "10:16, 10:35, 10:55" : "10:16 :35 :55" }
}

/// How much the widget fits in.
enum WidgetDensity: String, CaseIterable, Identifiable, Sendable {
    case compact, regular

    var id: String { rawValue }
    var name: String { self == .compact ? "Compact" : "Regular" }
    var detail: String { self == .compact ? "Smaller text, more trains" : "Larger text, fewer trains" }
}

struct WidgetStyle: Hashable, Sendable {
    var density: WidgetDensity = .compact
    var timeFormat: WidgetTimeFormat = .full
    var showArrival = false
    /// The most times a line may show. The widget shows fewer when fewer fit.
    var maxTimes = Board.mostPerLine

    /// Train times on each line where nothing measures what fits (VoiceOver, tests).
    var timesPerLine: Int {
        switch (timeFormat, density) {
        case (.short, .compact): return 5
        case (.short, .regular): return 4
        case (.full, .compact): return 4
        case (.full, .regular): return 3
        }
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
    static func string(_ times: [Date], arrivalOfFirst: Date? = nil, format: WidgetTimeFormat = .short) -> String {
        if format == .full {
            return times.enumerated().map { index, time in
                index == 0 ? clock(time) + (arrivalOfFirst.map { "→" + clock($0) } ?? "") : clock(time)
            }.joined(separator: ", ")
        }
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
    var style = WidgetStyle()
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
    /// Issues of a muted kind change nothing here. Muting delays also clears the delay
    /// marks worked out from live arrivals.
    mutating func apply(issues: [Issue], muted: Set<IssueKind>) {
        if muted.contains(.delay) {
            for index in groups.indices {
                groups[index].delay = .none
            }
        }
        for issue in issues where issue.isActive && !issue.detected && !muted.contains(issue.kind) {
            if issue.affectedLines.isEmpty {
                hasAlert = true
                continue
            }
            for index in groups.indices where issue.affects(from: station, to: groups[index].target) {
                groups[index].delay = .major
            }
        }
    }

    func board(at date: Date) -> Board {
        let visibleFrom = date.addingTimeInterval(-BoardPlan.grace)
        let upcoming = groups
            .map { group -> Group in
                var copy = group
                copy.trains = group.trains.filter { $0.time > visibleFrom }
                return copy
            }
            .filter { !$0.trains.isEmpty }

        guard let first = upcoming.first else {
            return Board(station: station, rows: [], perLine: style.timesPerLine, hasAlert: hasAlert)
        }

        func row(_ group: Group, label: String? = nil, delay: DelayLevel? = nil, count: Int) -> BoardRow {
            BoardRow(label: label ?? group.target.lineLabel, target: group.target, delay: delay ?? group.delay,
                     times: group.trains.prefix(count).map(\.time), arrival: arrival(in: group), timeFormat: style.timeFormat)
        }

        if upcoming.count >= 2 {
            let second = upcoming[1]
            let a = Array(first.trains.prefix(style.timesPerLine))
            let b = Array(second.trains.prefix(style.timesPerLine))
            // The same trains serve both destinations (for example Journal Square via Hoboken
            // late at night): list them once across both lines, named for both, as in "JSQ+HOB".
            let sameTrains = a.map(\.time) == b.map(\.time)
                && a.allSatisfy { $0.serves(second.target) }
                && b.allSatisfy { $0.serves(first.target) }
            if sameTrains {
                let both = row(first, label: "\(first.target.lineLabel)+\(second.target.lineLabel)",
                               delay: max(first.delay, second.delay), count: Board.mostPerLine * 2)
                return Board(station: station, rows: [both], perLine: style.timesPerLine, hasAlert: hasAlert)
            }
            return Board(station: station, rows: [row(first, count: Board.mostPerLine), row(second, count: Board.mostPerLine)],
                         perLine: style.timesPerLine, hasAlert: hasAlert)
        }

        return Board(station: station, rows: [row(first, count: Board.mostPerLine * 2)], perLine: style.timesPerLine, hasAlert: hasAlert)
    }

    private func arrival(in group: Group) -> Date? {
        guard style.showArrival, let train = group.trains.first else { return nil }
        return schedule.arrival(of: train, from: station, to: group.target)
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
