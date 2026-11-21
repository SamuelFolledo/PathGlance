import Foundation

enum GTFSError: LocalizedError {
    case download(Int)
    case missingFile(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .download(let status): return "Schedule download failed (HTTP \(status))."
        case .missingFile(let name): return "The schedule feed is missing \(name)."
        case .empty: return "The schedule feed had no usable departures."
        }
    }
}

/// Downloads PATH's published GTFS feed and reduces it to the compact `ScheduleData`
/// the widget reads.
enum GTFSImporter {
    /// PATH's GTFS feed, hosted by Trillium for the Port Authority.
    static let feedURL = URL(string: "https://data.trilliumtransit.com/gtfs/path-nj-us/path-nj-us.zip")!

    static func download() async throws -> ScheduleData {
        var request = URLRequest(url: feedURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw GTFSError.download(http.statusCode)
        }
        return try await parse(zip: data)
    }

    /// Parses off the main thread; the feed is a few megabytes of CSV.
    static func parse(zip data: Data) async throws -> ScheduleData {
        try await Task.detached(priority: .userInitiated) {
            try build(zip: data)
        }.value
    }

    static func build(zip data: Data) throws -> ScheduleData {
        let files = try ZipReader.entries(
            named: ["stops.txt", "trips.txt", "stop_times.txt", "calendar.txt", "calendar_dates.txt", "feed_info.txt"],
            in: data
        )
        func table(_ name: String) throws -> CSVTable {
            guard let file = files[name] else { throw GTFSError.missingFile(name) }
            return CSVTable(data: file)
        }

        // Stops: map every stop (platform, entrance or station) to one of the 13 stations.
        let stops = try table("stops.txt")
        var stopNames: [String: String] = [:]
        var stopParents: [String: String] = [:]
        var stopCoordinates: [String: (Double, Double)] = [:]
        for row in stops.rows {
            guard let id = stops.value(row, "stop_id") else { continue }
            stopNames[id] = stops.value(row, "stop_name") ?? ""
            if let parent = stops.value(row, "parent_station"), !parent.isEmpty {
                stopParents[id] = parent
            }
            if let lat = stops.value(row, "stop_lat").flatMap({ Double($0) }),
               let lon = stops.value(row, "stop_lon").flatMap({ Double($0) }) {
                stopCoordinates[id] = (lat, lon)
            }
        }
        var stationForStop: [String: Station] = [:]
        for id in stopNames.keys {
            let parent = stopParents[id]
            if let parent, let name = stopNames[parent], let station = Station.matching(gtfsStopName: name) {
                stationForStop[id] = station
            } else if let name = stopNames[id], let station = Station.matching(gtfsStopName: name) {
                stationForStop[id] = station
            } else if let (lat, lon) = stopCoordinates[id] ?? parent.flatMap({ stopCoordinates[$0] }) {
                let nearest = Station.nearest(latitude: lat, longitude: lon)
                if nearest.distance(toLatitude: lat, longitude: lon) < 400 {
                    stationForStop[id] = nearest
                }
            }
        }

        // Services.
        var serviceIndex: [String: Int] = [:]
        var services: [ServiceCalendar] = []
        func index(forService id: String) -> Int {
            if let existing = serviceIndex[id] { return existing }
            services.append(ServiceCalendar())
            serviceIndex[id] = services.count - 1
            return services.count - 1
        }
        if let file = files["calendar.txt"] {
            let calendar = CSVTable(data: file)
            let dayColumns = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            for row in calendar.rows {
                guard let id = calendar.value(row, "service_id") else { continue }
                let i = index(forService: id)
                services[i].weekdays = dayColumns.map { calendar.value(row, $0) == "1" }
                services[i].start = calendar.value(row, "start_date").flatMap({ Int($0) }) ?? 0
                services[i].end = calendar.value(row, "end_date").flatMap({ Int($0) }) ?? 0
            }
        }
        if let file = files["calendar_dates.txt"] {
            let dates = CSVTable(data: file)
            for row in dates.rows {
                guard let id = dates.value(row, "service_id"),
                      let date = dates.value(row, "date").flatMap({ Int($0) }) else { continue }
                let i = index(forService: id)
                if dates.value(row, "exception_type") == "1" {
                    services[i].added.append(date)
                } else {
                    services[i].removed.append(date)
                }
            }
        }

        // Trips.
        let trips = try table("trips.txt")
        var serviceForTrip: [String: Int] = [:]
        for row in trips.rows {
            guard let trip = trips.value(row, "trip_id"), let service = trips.value(row, "service_id") else { continue }
            serviceForTrip[trip] = index(forService: service)
        }

        // Stop times, grouped by trip.
        struct Call {
            var sequence: Int
            var station: Station
            var minute: Int
        }
        let stopTimes = try table("stop_times.txt")
        var calls: [String: [Call]] = [:]
        for row in stopTimes.rows {
            guard let trip = stopTimes.value(row, "trip_id"),
                  let stop = stopTimes.value(row, "stop_id"),
                  let station = stationForStop[stop],
                  let sequence = stopTimes.value(row, "stop_sequence").flatMap({ Int($0) }) else { continue }
            let time = [stopTimes.value(row, "departure_time"), stopTimes.value(row, "arrival_time")]
                .compactMap { $0 }
                .first { !$0.isEmpty }
            guard let time, let minute = minutes(fromGTFSTime: time) else { continue }
            calls[trip, default: []].append(Call(sequence: sequence, station: station, minute: minute))
        }

        var departures: [String: [Departure]] = [:]
        for (trip, unsorted) in calls {
            guard let service = serviceForTrip[trip] else { continue }
            let ordered = unsorted.sorted { $0.sequence < $1.sequence }
            var downstream = 0
            // Walk backwards so each stop knows every station still ahead of it.
            for call in ordered.reversed() {
                let reachable = downstream & ~call.station.bit
                if reachable != 0 {
                    departures[call.station.rawValue, default: []]
                        .append(Departure(minute: call.minute, service: service, downstream: reachable))
                }
                downstream |= call.station.bit
            }
        }
        guard !departures.isEmpty else { throw GTFSError.empty }
        for key in departures.keys {
            departures[key]?.sort { $0.minute < $1.minute }
        }

        var feedVersion: String?
        var feedEnd: Int?
        if let file = files["feed_info.txt"] {
            let info = CSVTable(data: file)
            if let row = info.rows.first {
                feedVersion = info.value(row, "feed_version")
                feedEnd = info.value(row, "feed_end_date").flatMap({ Int($0) })
            }
        }
        if feedEnd == nil {
            feedEnd = services.map(\.end).max().flatMap { $0 > 0 ? $0 : nil }
        }

        return ScheduleData(
            importedAt: Date(),
            feedVersion: feedVersion,
            feedEnd: feedEnd,
            services: services,
            departures: departures
        )
    }

    /// "25:10:00" is 1:10 AM on the next calendar day, still part of this service day.
    static func minutes(fromGTFSTime text: String) -> Int? {
        let parts = text.split(separator: ":")
        guard parts.count >= 2, let hours = Int(parts[0]), let minutes = Int(parts[1]) else { return nil }
        return hours * 60 + minutes
    }
}

/// Small CSV reader: quoted fields, escaped quotes, CRLF and a UTF-8 byte order mark.
struct CSVTable {
    let header: [String: Int]
    let rows: [[String]]

    init(data: Data) {
        var all = CSVTable.parse([UInt8](data))
        let names = all.isEmpty ? [] : all.removeFirst()
        var header: [String: Int] = [:]
        for (index, name) in names.enumerated() {
            header[name.trimmingCharacters(in: .whitespaces)] = index
        }
        self.header = header
        self.rows = all
    }

    /// Trimmed value of `column` in `row`, or nil when the column does not exist.
    func value(_ row: [String], _ column: String) -> String? {
        guard let index = header[column], index < row.count else { return nil }
        return row[index].trimmingCharacters(in: .whitespaces)
    }

    private static func parse(_ bytes: [UInt8]) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field: [UInt8] = []
        var inQuotes = false
        var i = 0
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            i = 3
        }

        func endField() {
            row.append(String(decoding: field, as: UTF8.self))
            field.removeAll(keepingCapacity: true)
        }
        func endRow() {
            endField()
            if !(row.count == 1 && row[0].isEmpty) {
                rows.append(row)
            }
            row = []
        }

        while i < bytes.count {
            let byte = bytes[i]
            if inQuotes {
                if byte == 34 { // "
                    if i + 1 < bytes.count, bytes[i + 1] == 34 {
                        field.append(34)
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(byte)
                }
            } else {
                switch byte {
                case 34: inQuotes = true
                case 44: endField() // ,
                case 10: endRow()   // \n
                case 13: break      // \r
                default: field.append(byte)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            endRow()
        }
        return rows
    }
}
