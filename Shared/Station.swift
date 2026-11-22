import Foundation

/// The 13 PATH stations. Case order is used as the bit position in `Departure.downstream`,
/// so append new cases at the end and re-import the schedule if this ever changes.
enum Station: String, CaseIterable, Codable, Identifiable, Sendable {
    case newark
    case harrison
    case journalSquare
    case groveStreet
    case exchangePlace
    case worldTradeCenter
    case newport
    case hoboken
    case christopherStreet
    case ninthStreet
    case fourteenthStreet
    case twentyThirdStreet
    case thirtyThirdStreet

    var id: String { rawValue }

    var index: Int { Station.allCases.firstIndex(of: self) ?? 0 }

    /// Bit used in `Departure.downstream`.
    var bit: Int { 1 << index }

    var name: String {
        switch self {
        case .newark: return "Newark"
        case .harrison: return "Harrison"
        case .journalSquare: return "Journal Square"
        case .groveStreet: return "Grove Street"
        case .exchangePlace: return "Exchange Place"
        case .worldTradeCenter: return "World Trade Center"
        case .newport: return "Newport"
        case .hoboken: return "Hoboken"
        case .christopherStreet: return "Christopher Street"
        case .ninthStreet: return "9th Street"
        case .fourteenthStreet: return "14th Street"
        case .twentyThirdStreet: return "23rd Street"
        case .thirtyThirdStreet: return "33rd Street"
        }
    }

    /// Used in the widget header: "From J Sq: 7:05".
    var shortName: String {
        switch self {
        case .newark: return "Newark"
        case .harrison: return "Harrison"
        case .journalSquare: return "J Sq"
        case .groveStreet: return "Grove"
        case .exchangePlace: return "Exch Pl"
        case .worldTradeCenter: return "WTC"
        case .newport: return "Newport"
        case .hoboken: return "Hoboken"
        case .christopherStreet: return "Chris St"
        case .ninthStreet: return "9th"
        case .fourteenthStreet: return "14th"
        case .twentyThirdStreet: return "23rd"
        case .thirtyThirdStreet: return "33rd"
        }
    }

    /// Used as the destination label at the start of a widget line.
    var lineLabel: String {
        switch self {
        case .newark: return "NWK"
        case .harrison: return "HAR"
        case .journalSquare: return "JSQ"
        case .groveStreet: return "GRV"
        case .exchangePlace: return "EXP"
        case .worldTradeCenter: return "WTC"
        case .newport: return "NEW"
        case .hoboken: return "HOB"
        case .christopherStreet: return "CHR"
        case .ninthStreet: return "9th"
        case .fourteenthStreet: return "14th"
        case .twentyThirdStreet: return "23rd"
        case .thirtyThirdStreet: return "33rd"
        }
    }

    /// Two or three characters for the round station badge.
    var badge: String {
        switch self {
        case .newark: return "NWK"
        case .harrison: return "HAR"
        case .journalSquare: return "JSQ"
        case .groveStreet: return "GRV"
        case .exchangePlace: return "EXP"
        case .worldTradeCenter: return "WTC"
        case .newport: return "NPT"
        case .hoboken: return "HOB"
        case .christopherStreet: return "CHR"
        case .ninthStreet: return "9"
        case .fourteenthStreet: return "14"
        case .twentyThirdStreet: return "23"
        case .thirtyThirdStreet: return "33"
        }
    }

    /// Station code used by the Port Authority real-time feed (`consideredStation`).
    var realtimeCode: String {
        switch self {
        case .newark: return "NWK"
        case .harrison: return "HAR"
        case .journalSquare: return "JSQ"
        case .groveStreet: return "GRV"
        case .exchangePlace: return "EXP"
        case .worldTradeCenter: return "WTC"
        case .newport: return "NEW"
        case .hoboken: return "HOB"
        case .christopherStreet: return "CHR"
        case .ninthStreet: return "09S"
        case .fourteenthStreet: return "14S"
        case .twentyThirdStreet: return "23S"
        case .thirtyThirdStreet: return "33S"
        }
    }

    var latitude: Double {
        switch self {
        case .newark: return 40.7345
        case .harrison: return 40.7393
        case .journalSquare: return 40.7332
        case .groveStreet: return 40.7196
        case .exchangePlace: return 40.7163
        case .worldTradeCenter: return 40.7116
        case .newport: return 40.7268
        case .hoboken: return 40.7359
        case .christopherStreet: return 40.7330
        case .ninthStreet: return 40.7343
        case .fourteenthStreet: return 40.7374
        case .twentyThirdStreet: return 40.7429
        case .thirtyThirdStreet: return 40.7491
        }
    }

    var longitude: Double {
        switch self {
        case .newark: return -74.1638
        case .harrison: return -74.1558
        case .journalSquare: return -74.0628
        case .groveStreet: return -74.0431
        case .exchangePlace: return -74.0329
        case .worldTradeCenter: return -74.0113
        case .newport: return -74.0338
        case .hoboken: return -74.0292
        case .christopherStreet: return -74.0071
        case .ninthStreet: return -73.9990
        case .fourteenthStreet: return -73.9969
        case .twentyThirdStreet: return -73.9929
        case .thirtyThirdStreet: return -73.9883
        }
    }

    /// Approximate distance in meters. Accurate enough at this scale and keeps
    /// the shared code free of CoreLocation.
    func distance(toLatitude lat: Double, longitude lon: Double) -> Double {
        let metersPerDegree = 111_320.0
        let dLat = (lat - latitude) * metersPerDegree
        let dLon = (lon - longitude) * metersPerDegree * cos(latitude * .pi / 180)
        return (dLat * dLat + dLon * dLon).squareRoot()
    }

    static func nearest(latitude: Double, longitude: Double) -> Station {
        var best = Station.journalSquare
        var bestDistance = Double.greatestFiniteMagnitude
        for station in Station.allCases {
            let d = station.distance(toLatitude: latitude, longitude: longitude)
            if d < bestDistance {
                bestDistance = d
                best = station
            }
        }
        return best
    }

    /// Lowercased fragments that identify this station in a GTFS `stop_name`.
    private var gtfsKeywords: [String] {
        switch self {
        case .newark: return ["newark"]
        case .harrison: return ["harrison"]
        case .journalSquare: return ["journal"]
        case .groveStreet: return ["grove"]
        case .exchangePlace: return ["exchange"]
        case .worldTradeCenter: return ["world trade", "wtc"]
        case .newport: return ["newport"]
        case .hoboken: return ["hoboken"]
        case .christopherStreet: return ["christopher"]
        case .ninthStreet: return ["9th", "ninth"]
        case .fourteenthStreet: return ["14th", "fourteenth"]
        case .twentyThirdStreet: return ["23rd", "twenty-third", "twenty third"]
        case .thirtyThirdStreet: return ["33rd", "thirty-third", "thirty third"]
        }
    }

    /// The station whose keyword appears earliest in the name, so "World Trade Center
    /// (Newark bound)" resolves to World Trade Center.
    static func matching(gtfsStopName name: String) -> Station? {
        let lowered = name.lowercased()
        var best: Station?
        var bestIndex = lowered.endIndex
        for station in Station.allCases {
            for keyword in station.gtfsKeywords {
                if let range = lowered.range(of: keyword), range.lowerBound < bestIndex {
                    best = station
                    bestIndex = range.lowerBound
                }
            }
        }
        return best
    }
}
