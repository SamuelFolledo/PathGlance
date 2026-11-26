import Foundation

/// Where an issue applies, read out of PATH's own wording. PATH writes alerts as free
/// text, so this only knows what the text names: a station by its name or short form,
/// a line by its code ("JSQ-33").
struct IssuePlace: Equatable, Sendable {
    var stations: Set<Station> = []
    /// Line codes, as in `PathLines.stations`.
    var lines: Set<String> = []
}

/// Why an issue is shown to someone looking at trains from one station to another.
enum IssueRelevance: Equatable, Sendable {
    /// It names the station they are at.
    case station
    /// It names a line that runs from their station to the destination on screen.
    case line
}

enum IssueMatcher {
    /// What PATH calls each station in its alerts, lowercased. Whole words only.
    static let names: [Station: [String]] = [
        .newark: ["newark", "nwk"],
        .harrison: ["harrison"],
        .journalSquare: ["journal square", "journal sq", "jsq"],
        .groveStreet: ["grove street", "grove st", "grove"],
        .exchangePlace: ["exchange place", "exchange pl"],
        .worldTradeCenter: ["world trade center", "wtc"],
        .newport: ["newport"],
        .hoboken: ["hoboken", "hob"],
        .christopherStreet: ["christopher street", "christopher st", "christopher"],
        .ninthStreet: ["9th street", "9th st", "9 st", "ninth street"],
        .fourteenthStreet: ["14th street", "14th st", "14 st"],
        .twentyThirdStreet: ["23rd street", "23rd st", "23 st"],
        .thirtyThirdStreet: ["33rd street", "33rd st", "33 st"],
    ]

    /// The stations and lines an issue names. A delay the app noticed itself carries its
    /// station and destination in its id.
    static func place(of issue: Issue) -> IssuePlace {
        if issue.detected {
            let parts = issue.id.split(separator: "-")
            guard parts.count >= 3, let origin = Station(rawValue: String(parts[1])), let target = Station(rawValue: String(parts[2])) else {
                return IssuePlace()
            }
            return IssuePlace(stations: [origin], lines: Set(lines(from: origin, to: target)))
        }
        let text = ([issue.title] + issue.updates.flatMap { [$0.subject, $0.message] }).joined(separator: " ")
        return place(in: text, affectedLines: issue.affectedLines)
    }

    /// `affectedLines` are the lines PATH reports as delayed or suspended. When there are
    /// any, they are the lines; a line only mentioned as "running normally" is left out.
    static func place(in text: String, affectedLines: [String] = []) -> IssuePlace {
        var place = IssuePlace()
        var rest = text.uppercased()
        for code in PathLines.stations.keys.sorted() where rest.contains(code) {
            place.lines.insert(code)
            // "JSQ-33" must not also count as the stations Journal Square and 33rd Street.
            rest = rest.replacingOccurrences(of: code, with: " ")
        }
        if !affectedLines.isEmpty { place.lines = Set(affectedLines) }
        let lowered = rest.lowercased()
        for (station, names) in names {
            for name in names where containsWord(name, in: lowered) {
                place.stations.insert(station)
                break
            }
        }
        return place
    }

    /// The lines that run from `origin` to `target`.
    static func lines(from origin: Station, to target: Station) -> [String] {
        PathLines.stations.keys.sorted().filter { code in
            guard let stations = PathLines.stations[code] else { return false }
            return stations.contains(origin) && stations.contains(target)
        }
    }

    /// Whether an issue matters to someone at `station` looking at trains to `target`.
    /// `nil` when the text names neither: the issue stays on the Issues tab only.
    static func relevance(of issue: Issue, station: Station, target: Station?) -> IssueRelevance? {
        let place = place(of: issue)
        if place.stations.contains(station), !issue.detected { return .station }
        if let target, !place.lines.isDisjoint(with: lines(from: station, to: target)) { return .line }
        return nil
    }

    private static func containsWord(_ word: String, in text: String) -> Bool {
        var start = text.startIndex
        while let range = text.range(of: word, range: start..<text.endIndex) {
            let before = range.lowerBound == text.startIndex ? nil : text[text.index(before: range.lowerBound)]
            let after = range.upperBound == text.endIndex ? nil : text[range.upperBound]
            let isWordChar: (Character?) -> Bool = { $0.map { $0.isLetter || $0.isNumber } ?? false }
            if !isWordChar(before), !isWordChar(after) { return true }
            start = range.upperBound
        }
        return false
    }
}
