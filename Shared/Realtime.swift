import Foundation

struct RealtimeArrival: Sendable {
    let station: Station
    let headSign: String
    let arrival: Date
}

/// The Port Authority feed behind the PATH schedules page. It only covers the next
/// train or two per direction, so it adjusts the schedule and never replaces it.
enum RealtimeFeed {
    static let url = URL(string: "https://www.panynj.gov/bin/portauthority/ridepath.json")!

    /// Returns an empty list on any failure so callers fall back to the schedule.
    static func fetch(timeout: TimeInterval = 6) async -> [RealtimeArrival] {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return []
        }
        let now = Date()
        var arrivals: [RealtimeArrival] = []
        for result in payload.results {
            guard let station = Station.allCases.first(where: { $0.realtimeCode == result.consideredStation }) else {
                continue
            }
            for destination in result.destinations ?? [] {
                for message in destination.messages ?? [] {
                    guard let headSign = message.headSign, let seconds = message.secondsToArrival?.value else {
                        continue
                    }
                    arrivals.append(RealtimeArrival(
                        station: station,
                        headSign: headSign,
                        arrival: now.addingTimeInterval(TimeInterval(max(seconds, 0)))
                    ))
                }
            }
        }
        return arrivals
    }

    // MARK: Head sign matching

    private static let lines: [[Station]] = [
        [.newark, .harrison, .journalSquare, .groveStreet, .exchangePlace, .worldTradeCenter],
        [.journalSquare, .groveStreet, .newport, .christopherStreet, .ninthStreet, .fourteenthStreet, .twentyThirdStreet, .thirtyThirdStreet],
        [.hoboken, .christopherStreet, .ninthStreet, .fourteenthStreet, .twentyThirdStreet, .thirtyThirdStreet],
        [.hoboken, .newport, .exchangePlace, .worldTradeCenter],
    ]

    /// Nights and weekends: Journal Square to 33rd Street by way of Hoboken.
    private static let viaHobokenLine: [Station] = [
        .journalSquare, .groveStreet, .newport, .hoboken, .christopherStreet, .ninthStreet,
        .fourteenthStreet, .twentyThirdStreet, .thirtyThirdStreet,
    ]

    /// Whether a train with this head sign, boarding at `origin`, stops at `target`.
    static func serves(headSign: String, from origin: Station, to target: Station) -> Bool {
        let sign = headSign.lowercased()
        let terminal: Station
        if sign.contains("world trade") || sign.contains("wtc") {
            terminal = .worldTradeCenter
        } else if sign.contains("33") {
            terminal = .thirtyThirdStreet
        } else if sign.contains("journal") {
            terminal = .journalSquare
        } else if sign.contains("newark") {
            terminal = .newark
        } else if sign.contains("hoboken") {
            terminal = .hoboken
        } else {
            return false
        }
        let viaHoboken = sign.contains("via hob")

        func reaches(on line: [Station]) -> Bool {
            for path in [line, Array(line.reversed())] {
                guard path.last == terminal,
                      let originIndex = path.firstIndex(of: origin),
                      let targetIndex = path.firstIndex(of: target) else { continue }
                if targetIndex > originIndex { return true }
            }
            return false
        }

        func runs(on line: [Station]) -> Bool {
            line.contains(origin) && (line.first == terminal || line.last == terminal)
        }

        if viaHoboken {
            return reaches(on: viaHobokenLine)
        }
        let regular = lines.filter(runs(on:))
        if !regular.isEmpty {
            return regular.contains(where: reaches(on:))
        }
        // The feed sometimes drops "via Hoboken" from the sign at intermediate stations.
        return reaches(on: viaHobokenLine)
    }

    // MARK: Decoding

    private struct Payload: Decodable {
        let results: [StationResult]
    }

    private struct StationResult: Decodable {
        let consideredStation: String
        let destinations: [Destination]?
    }

    private struct Destination: Decodable {
        let messages: [Message]?
    }

    private struct Message: Decodable {
        let headSign: String?
        let secondsToArrival: FlexibleInt?
    }

    /// The feed sends numbers as strings ("68"). Accept either form.
    private struct FlexibleInt: Decodable {
        let value: Int?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let int = try? container.decode(Int.self) {
                value = int
            } else if let string = try? container.decode(String.self) {
                value = Int(string.trimmingCharacters(in: .whitespaces))
            } else {
                value = nil
            }
        }
    }
}
