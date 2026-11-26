import Foundation
@testable import PathGlance

/// A made-up but realistic PATH timetable, in the shape of the page PATH's website serves,
/// so tests go through the real importer. Weekdays run every 10 minutes, Saturdays every
/// 20 starting 3 minutes later, and Sundays every 30 starting 7 minutes later, so the three
/// day types never share a departure time.
enum Fixture {
    private struct Line {
        var name: String
        var headers: [String]
        /// Minutes after leaving the first station.
        var offsets: [Int]
        /// First and last departure, minutes after midnight.
        var first: Int
        var last: Int
        /// Departures every `interval * factor` minutes.
        var factor = 1
    }

    private static func reversed(_ line: Line, name: String) -> Line {
        let total = line.offsets.last ?? 0
        var headers = Array(line.headers.reversed())
        headers = headers.enumerated().map { index, header in
            let station = header.replacingOccurrences(of: "Arrival at ", with: "").replacingOccurrences(of: " Departure", with: "")
            return index == headers.count - 1 ? "Arrival at \(station)" : "\(station) Departure"
        }
        return Line(name: name, headers: headers, offsets: line.offsets.reversed().map { total - $0 },
                    first: line.first, last: line.last, factor: line.factor)
    }

    private static let lines: [Line] = {
        let newark = Line(name: "Newark - World Trade Center",
                          headers: ["Newark Departure", "Harrison Departure", "JSQ Departure", "Grove St Departure", "Exchange Departure", "Arrival at WTC"],
                          offsets: [0, 2, 13, 17, 20, 25], first: 0, last: 23 * 60 + 30)
        let direct = Line(name: "Journal Square - 33 Street",
                          headers: ["JSQ Departure", "Grove St Departure", "Newport Departure", "Chris St Departure", "9 St Departure", "14 St Departure", "23 St Departure", "Arrival at 33 St"],
                          offsets: [0, 4, 8, 16, 17, 19, 20, 23], first: 6 * 60, last: 22 * 60 + 50)
        // Overnight the Journal Square trains detour through Hoboken. The last ones run past midnight.
        let viaEarly = Line(name: "Journal Square - 33 Street (via Hoboken)",
                            headers: ["JSQ Departure", "Grove St Departure", "Newport Departure", "Hoboken Departure", "Chris St Departure", "9 St Departure", "14 St Departure", "23 St Departure", "Arrival at 33 St"],
                            offsets: [0, 4, 8, 16, 25, 26, 28, 29, 32], first: 0, last: 5 * 60 + 40, factor: 2)
        var viaLate = viaEarly
        viaLate.first = 23 * 60
        viaLate.last = 23 * 60 + 40
        let hoboken33 = Line(name: "Hoboken - 33 Street",
                             headers: ["Hoboken Departure", "Chris St Departure", "9 St Departure", "14 St Departure", "23 St Departure", "Arrival at 33 St"],
                             offsets: [0, 9, 10, 12, 13, 16], first: 6 * 60 + 5, last: 22 * 60 + 55)
        let hobokenWTC = Line(name: "Hoboken - World Trade Center",
                              headers: ["Hoboken Departure", "Newport Departure", "Exchange Departure", "Arrival at WTC"],
                              offsets: [0, 3, 6, 11], first: 6 * 60, last: 22 * 60 + 40, factor: 2)
        return [
            newark, reversed(newark, name: "World Trade Center - Newark"),
            direct, reversed(direct, name: "33 Street - Journal Square"),
            viaEarly, viaLate,
            reversed(viaEarly, name: "33 Street - Journal Square (via Hoboken)"), reversed(viaLate, name: "33 Street - Journal Square (via Hoboken)"),
            hoboken33, reversed(hoboken33, name: "33 Street - Hoboken"),
            hobokenWTC, reversed(hobokenWTC, name: "World Trade Center - Hoboken"),
        ]
    }()

    static func clock(_ minute: Int) -> String {
        let wrapped = minute % (24 * 60)
        let hour = wrapped / 60
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", twelve, wrapped % 60, hour < 12 ? "AM" : "PM")
    }

    private static func table(_ line: Line, interval: Int, shift: Int) -> String {
        var html = "<table><tbody><tr>" + line.headers.map { "<td rowspan=\"2\"><b>\($0.replacingOccurrences(of: " ", with: "<br>\r\n "))</b></td>" }.joined() + "</tr><tr></tr>"
        var start = line.first + shift
        while start <= line.last + shift {
            html += "<tr>" + line.offsets.map { "<td>\(clock(start + $0))</td>" }.joined() + "</tr>"
            start += interval * line.factor
        }
        return html + "</tbody></table>"
    }

    private static func accordionList(title: String?, interval: Int, shift: Int = 0, skip9thAnd23rdOvernight: Bool = false) -> [String: Any] {
        var items: [String: Any] = [:]
        for (index, line) in lines.enumerated() {
            var html = table(line, interval: interval, shift: shift)
            if skip9thAnd23rdOvernight, line.name.contains("via Hoboken") {
                // Overnight trains pass 9th and 23rd without stopping, as PATH's do.
                html = dashOut(html, columns: line.headers.indices.filter { line.headers[$0].hasPrefix("9 St") || line.headers[$0].hasPrefix("23 St") })
            }
            items["accordion_\(index)"] = [
                ":type": "portauthority/components/Accordion",
                "accordionLabel": "<p>\(line.name)</p>",
                // PATH's page nests the table under a child component that is itself named "text".
                ":items": ["text": [":type": "portauthority/components/Text", "text": html]],
            ]
        }
        var list: [String: Any] = [":type": "portauthority/components/AccordionList", ":items": items]
        if let title { list["title"] = title }
        return list
    }

    private static func dashOut(_ html: String, columns: [Int]) -> String {
        html.components(separatedBy: "<tr>").enumerated().map { index, row -> String in
            guard index > 1 else { return row }
            var cells = row.components(separatedBy: "<td>")
            for column in columns where cells.indices.contains(column + 1) {
                let tail = cells[column + 1].range(of: "</td>").map { String(cells[column + 1][$0.lowerBound...]) } ?? ""
                cells[column + 1] = "---" + tail
            }
            return cells.joined(separator: "<td>")
        }.joined(separator: "<tr>")
    }

    /// The page model as PATH's site would serve it.
    static func pageModel(effective: String = "Effective November 16, 2026") -> Data {
        let weekday: [String: Any] = [
            "title": "Weekday Schedules",
            ":items": ["root": [":items": [
                "textblock": [":type": "portauthority/components/TextBlock", "text": "<p><b>\(effective)</b></p><p>Trains may leave up to three minutes earlier or later.</p>"],
                "accordionlist": accordionList(title: nil, interval: 10, skip9thAnd23rdOvernight: true),
            ]]],
        ]
        let weekend: [String: Any] = [
            "title": "Weekend Schedules",
            ":items": ["root": [":items": [
                "saturday": accordionList(title: "Saturday Schedule:", interval: 20, shift: 3),
                "sunday": accordionList(title: "Sunday Schedule:", interval: 30, shift: 7),
            ]]],
        ]
        // An old one-off page PATH leaves on its site; the importer must ignore it.
        let stale: [String: Any] = [
            "title": "Weekend-Apr5-6",
            ":items": ["root": [":items": ["old": accordionList(title: "Saturday, April 5, 2025", interval: 60)]]],
        ]
        let root: [String: Any] = [":children": [
            "/path/en/schedules-maps/weekday-schedules": weekday,
            "/path/en/schedules-maps/weekend-schedules": weekend,
            "/path/en/schedules-maps/weekend-schedules/Weekend-Apr5-6": stale,
        ]]
        return try! JSONSerialization.data(withJSONObject: root)
    }

    static let schedule: ScheduleData = try! WebTimetableImporter.build(pageModel: pageModel())

    /// A New York wall-clock time, as "2026-11-24 07:05". Nov 24, 2026 is a Tuesday,
    /// Nov 28 a Saturday and Nov 29 a Sunday.
    static func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = PathTime.calendar
        formatter.timeZone = PathTime.calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    static func clocks(_ trains: [TrainTime]) -> [String] {
        trains.map { CompactTimes.clock($0.time) }
    }

    static func arrival(_ station: Station, _ headSign: String, at date: Date) -> RealtimeArrival {
        RealtimeArrival(station: station, headSign: headSign, arrival: date)
    }
}
