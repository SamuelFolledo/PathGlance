import Foundation

/// A tab on the Issues screen: one line, or the two Hoboken lines together.
enum IssueTab: String, CaseIterable, Identifiable, Sendable {
    case journalSquare33
    case newarkWorldTrade
    case hoboken

    var id: String { rawValue }

    /// Line codes, as in `PathLines.stations`, in the order their strips are drawn.
    var lines: [String] {
        switch self {
        case .journalSquare33: return ["JSQ-33"]
        case .newarkWorldTrade: return ["NWK-WTC"]
        case .hoboken: return ["HOB-33", "HOB-WTC"]
        }
    }

    var title: String {
        switch self {
        case .journalSquare33: return "JSQ–33rd"
        case .newarkWorldTrade: return "NWK–WTC"
        case .hoboken: return "Hoboken"
        }
    }

    var spokenTitle: String {
        switch self {
        case .journalSquare33: return "Journal Square to 33rd Street line"
        case .newarkWorldTrade: return "Newark to World Trade Center line"
        case .hoboken: return "Hoboken lines"
        }
    }

    /// The ends of this tab's lines, which is what "Lines preferred" orders.
    var terminals: [Station] {
        switch self {
        case .journalSquare33: return [.journalSquare, .thirtyThirdStreet]
        case .newarkWorldTrade: return [.newark, .worldTradeCenter]
        case .hoboken: return [.hoboken]
        }
    }
}

/// One stop on a line's strip, with the open issues that name it.
struct IssueStop: Equatable, Identifiable, Sendable {
    var station: Station
    var issues: [Issue]
    var id: String { station.rawValue }
}

/// One line as the Issues tab draws it.
struct IssueStrip: Equatable, Identifiable, Sendable {
    /// "JSQ-33"
    var code: String
    /// Issues that name the line and none of its stops.
    var wholeLine: [Issue]
    var stops: [IssueStop]
    var id: String { code }

    /// Every issue on the strip, once each.
    var issues: [Issue] {
        var seen = Set<String>()
        return (wholeLine + stops.flatMap(\.issues)).filter { seen.insert($0.id).inserted }
    }
}

/// Sorts open issues onto the lines and stops PATH's wording names (`IssueMatcher`).
enum IssueBoard {
    /// "JSQ–33rd" for "JSQ-33".
    static func name(of code: String) -> String {
        switch code {
        case "JSQ-33": return "JSQ–33rd"
        case "NWK-WTC": return "NWK–WTC"
        case "HOB-33": return "HOB–33rd"
        case "HOB-WTC": return "HOB–WTC"
        default: return code
        }
    }

    /// The tabs in the user's preferred order: a tab stands where the first of its
    /// lines' ends stands in "Lines preferred". The standard order gives JSQ–33rd,
    /// NWK–WTC, Hoboken.
    static func tabs(order: [Station]) -> [IssueTab] {
        func rank(_ tab: IssueTab) -> Int {
            tab.terminals.compactMap { order.firstIndex(of: $0) }.min() ?? order.count
        }
        return IssueTab.allCases.enumerated().sorted { a, b in
            (rank(a.element), a.offset) < (rank(b.element), b.offset)
        }.map(\.element)
    }

    /// The stops drawn for a line. JSQ–33rd only calls at Hoboken at nights and weekends,
    /// so Hoboken is drawn on it only when an issue on that line names it.
    static func stops(of code: String, naming named: Set<Station> = []) -> [Station] {
        let all = PathLines.stations[code] ?? []
        guard code == "JSQ-33", !named.contains(.hoboken) else { return all }
        return all.filter { $0 != .hoboken }
    }

    /// Whether an issue belongs on a line, and at which of its stops.
    /// - An issue that names lines belongs to those lines only: at the stops of theirs it
    ///   names, or to the whole line when it names none.
    /// - An issue that names stations and no line (an elevator) belongs at those stops on
    ///   every line that calls there.
    /// - An issue that names neither belongs to no line (`other`).
    static func stations(of issue: Issue, on code: String) -> (isOnLine: Bool, stops: Set<Station>) {
        let place = IssueMatcher.place(of: issue)
        let lineStops = Set(PathLines.stations[code] ?? [])
        if place.lines.isEmpty {
            let stops = place.stations.intersection(lineStops)
            return (!stops.isEmpty, stops)
        }
        guard place.lines.contains(code) else { return (false, []) }
        return (true, place.stations.intersection(lineStops))
    }

    /// `issues` laid out on one line. Newest issue first at each stop.
    static func strip(_ code: String, issues: [Issue]) -> IssueStrip {
        var whole: [Issue] = []
        var byStop: [Station: [Issue]] = [:]
        var named = Set<Station>()
        for issue in issues {
            let found = stations(of: issue, on: code)
            guard found.isOnLine else { continue }
            if found.stops.isEmpty {
                whole.append(issue)
            } else {
                for stop in found.stops { byStop[stop, default: []].append(issue) }
                if !IssueMatcher.place(of: issue).lines.isEmpty { named.formUnion(found.stops) }
            }
        }
        let stops = stops(of: code, naming: named).map { IssueStop(station: $0, issues: byStop[$0] ?? []) }
        return IssueStrip(code: code, wholeLine: whole, stops: stops)
    }

    /// Issues whose wording names no line and no station. They show under every tab, so
    /// nothing PATH says is hidden.
    static func other(_ issues: [Issue]) -> [Issue] {
        issues.filter { issue in
            let place = IssueMatcher.place(of: issue)
            return place.lines.isEmpty && place.stations.isEmpty
        }
    }

    /// How many issues a tab counts under its name: those on its lines whose kind is not
    /// muted. Unplaced ("other") issues are not any one line's.
    static func count(_ tab: IssueTab, issues: [Issue], muted: Set<IssueKind>) -> Int {
        var seen = Set<String>()
        for code in tab.lines {
            for issue in strip(code, issues: issues).issues where !muted.contains(issue.kind) {
                seen.insert(issue.id)
            }
        }
        return seen.count
    }
}
