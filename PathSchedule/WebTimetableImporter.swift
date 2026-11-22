import Foundation

enum WebTimetableError: LocalizedError {
    case download(Int)
    case unexpectedFormat(String)

    var errorDescription: String? {
        switch self {
        case .download(let status): return "Timetable download failed (HTTP \(status))."
        case .unexpectedFormat(let detail): return "PATH's timetable page has changed (\(detail))."
        }
    }
}

/// Reads the timetables PATH shows on its Schedules and Maps pages. This is the data
/// behind the web page, not a documented API, so every step checks what it finds and
/// throws rather than producing a partial schedule.
///
/// The page has one table per line and direction for weekdays, Saturdays and Sundays.
/// Each row is one train, each column a station.
enum WebTimetableImporter {
    static let pageURL = URL(string: "https://www.panynj.gov/content/path/en/schedules-maps.model.json")!

    static func download() async throws -> ScheduleData {
        var request = URLRequest(url: pageURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw WebTimetableError.download(http.statusCode)
        }
        return try await Task.detached(priority: .userInitiated) {
            try build(pageModel: data)
        }.value
    }

    private enum DayType: Int, CaseIterable {
        case weekday, saturday, sunday

        var calendar: ServiceCalendar {
            var weekdays = Array(repeating: false, count: 7)
            switch self {
            case .weekday: for index in 0..<5 { weekdays[index] = true }
            case .saturday: weekdays[5] = true
            case .sunday: weekdays[6] = true
            }
            // The page carries no end date; it always shows the timetable in effect.
            return ServiceCalendar(weekdays: weekdays, start: 0, end: 99_999_999)
        }
    }

    static func build(pageModel data: Data) throws -> ScheduleData {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pages = root[":children"] as? [String: Any] else {
            throw WebTimetableError.unexpectedFormat("no pages")
        }
        func page(endingWith suffix: String) throws -> [String: Any] {
            guard let match = pages.first(where: { $0.key.hasSuffix(suffix) })?.value as? [String: Any] else {
                throw WebTimetableError.unexpectedFormat("missing \(suffix)")
            }
            return match
        }
        let weekdayPage = try page(endingWith: "/schedules-maps/weekday-schedules")
        let weekendPage = try page(endingWith: "/schedules-maps/weekend-schedules")

        var departures: [String: [Departure]] = [:]
        var trainCounts = [DayType: Int]()

        func addLists(_ lists: [[String: Any]], dayType: (String) -> DayType?) throws {
            for list in lists {
                let title = (list["title"] as? String) ?? ""
                guard let day = dayType(title) else {
                    throw WebTimetableError.unexpectedFormat("unknown day \"\(title)\"")
                }
                var html: [String] = []
                collectText(in: list, into: &html)
                for table in html.flatMap(tables(in:)) {
                    trainCounts[day, default: 0] += try add(table: table, service: day.rawValue, to: &departures)
                }
            }
        }

        try addLists(accordionLists(in: weekdayPage)) { _ in .weekday }
        try addLists(accordionLists(in: weekendPage)) { title in
            let lowered = title.lowercased()
            if lowered.contains("saturday") { return .saturday }
            if lowered.contains("sunday") { return .sunday }
            return nil
        }

        for day in DayType.allCases where trainCounts[day, default: 0] < 100 {
            throw WebTimetableError.unexpectedFormat("only \(trainCounts[day, default: 0]) trains for day type \(day)")
        }
        for station in Station.allCases where (departures[station.rawValue] ?? []).isEmpty {
            throw WebTimetableError.unexpectedFormat("no trains from \(station.name)")
        }
        for key in departures.keys {
            departures[key]?.sort { $0.minute < $1.minute }
        }

        var pageText: [String] = []
        collectText(in: weekdayPage, into: &pageText)
        let effective = pageText.lazy
            .map(plainText)
            .compactMap { text -> String? in
                guard let range = text.range(of: "Effective [A-Za-z]+ [0-9]{1,2}, [0-9]{4}", options: .regularExpression) else {
                    return nil
                }
                return String(text[range])
            }
            .first

        return ScheduleData(
            importedAt: Date(),
            feedVersion: effective,
            feedEnd: nil,
            services: DayType.allCases.map(\.calendar),
            departures: departures
        )
    }

    // MARK: Page structure

    /// Every "AccordionList" component under `node`, in page order where the page states one.
    private static func accordionLists(in node: [String: Any]) -> [[String: Any]] {
        if let type = node[":type"] as? String, type.hasSuffix("/AccordionList") {
            return [node]
        }
        var found: [[String: Any]] = []
        for (_, value) in node {
            if let child = value as? [String: Any] {
                found += accordionLists(in: child)
            }
        }
        return found
    }

    /// Every rich-text `text` value under `node`.
    private static func collectText(in node: Any, into result: inout [String]) {
        if let dictionary = node as? [String: Any] {
            // A component's own HTML is its "text" string; child components can also be keyed "text".
            for (key, value) in dictionary {
                if key == "text", let text = value as? String {
                    result.append(text)
                } else {
                    collectText(in: value, into: &result)
                }
            }
        } else if let array = node as? [Any] {
            for value in array {
                collectText(in: value, into: &result)
            }
        }
    }

    // MARK: Tables

    private static let tablePattern = try! NSRegularExpression(pattern: "<table[^>]*>(.*?)</table>", options: [.caseInsensitive, .dotMatchesLineSeparators])
    private static let rowPattern = try! NSRegularExpression(pattern: "<tr[^>]*>(.*?)</tr>", options: [.caseInsensitive, .dotMatchesLineSeparators])
    private static let cellPattern = try! NSRegularExpression(pattern: "<t[dh][^>]*>(.*?)</t[dh]>", options: [.caseInsensitive, .dotMatchesLineSeparators])

    private static func captures(of pattern: NSRegularExpression, in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    /// Tables as rows of plain-text cells. Empty rows are dropped.
    private static func tables(in html: String) -> [[[String]]] {
        captures(of: tablePattern, in: html).map { table in
            captures(of: rowPattern, in: table)
                .map { row in captures(of: cellPattern, in: row).map(plainText) }
                .filter { !$0.isEmpty }
        }
    }

    private static func plainText(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Adds one table's trains and returns how many it held.
    private static func add(table: [[String]], service: Int, to departures: inout [String: [Departure]]) throws -> Int {
        guard let header = table.first, header.count >= 2 else { return 0 }
        let stations = try header.map { cell -> Station in
            guard let station = station(forHeader: cell) else {
                throw WebTimetableError.unexpectedFormat("unknown station \"\(cell)\"")
            }
            return station
        }

        var trains = 0
        for row in table.dropFirst() {
            guard row.count == stations.count else {
                throw WebTimetableError.unexpectedFormat("row with \(row.count) of \(stations.count) columns")
            }
            // Stops in travel order. A train that runs past midnight keeps counting up.
            var calls: [(station: Station, minute: Int)] = []
            var previous = -1
            for (station, cell) in zip(stations, row) {
                if cell.isEmpty || cell.allSatisfy({ $0 == "-" || $0 == "–" || $0 == "—" }) { continue } // skips this stop
                guard var minute = minutes(fromClock: cell) else {
                    throw WebTimetableError.unexpectedFormat("unreadable time \"\(cell)\"")
                }
                while minute < previous { minute += 24 * 60 }
                previous = minute
                calls.append((station, minute))
            }
            guard calls.count >= 2 else { continue }
            trains += 1

            var downstream = 0
            // Walk backwards so each stop knows every station still ahead of it.
            for call in calls.reversed() {
                let reachable = downstream & ~call.station.bit
                if reachable != 0 {
                    departures[call.station.rawValue, default: []]
                        .append(Departure(minute: call.minute, service: service, downstream: reachable))
                }
                downstream |= call.station.bit
            }
        }
        return trains
    }

    /// Column headers read "JSQ Departure", "9 St Departure", "Arrival at 33 St" and so on.
    static func station(forHeader header: String) -> Station? {
        let name = header.lowercased()
            .replacingOccurrences(of: "departure", with: "")
            .replacingOccurrences(of: "arrival at", with: "")
            .replacingOccurrences(of: "arrival", with: "")
            .trimmingCharacters(in: .whitespaces)
        let prefixes: [(String, Station)] = [
            ("jsq", .journalSquare), ("journal", .journalSquare),
            ("grove", .groveStreet), ("newport", .newport),
            ("chris", .christopherStreet),
            ("9 ", .ninthStreet), ("9th", .ninthStreet),
            ("14", .fourteenthStreet), ("23", .twentyThirdStreet), ("33", .thirtyThirdStreet),
            ("exchange", .exchangePlace), ("wtc", .worldTradeCenter), ("world trade", .worldTradeCenter),
            ("newark", .newark), ("harrison", .harrison), ("hoboken", .hoboken),
        ]
        return prefixes.first { (name + " ").hasPrefix($0.0) }?.1
    }

    /// "5:49 AM" to minutes after midnight.
    static func minutes(fromClock text: String) -> Int? {
        let upper = text.uppercased()
        let isPM = upper.contains("PM")
        guard isPM || upper.contains("AM") else { return nil }
        let digits = upper.replacingOccurrences(of: "AM", with: "").replacingOccurrences(of: "PM", with: "")
            .trimmingCharacters(in: .whitespaces)
        let parts = digits.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (1...12).contains(hour), (0..<60).contains(minute) else { return nil }
        return (hour % 12 + (isPM ? 12 : 0)) * 60 + minute
    }
}
