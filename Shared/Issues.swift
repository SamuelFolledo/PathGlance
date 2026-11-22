import Foundation

enum IssueKind: String, Codable, CaseIterable, Sendable {
    case delay
    case suspension
    case plannedWork
    case elevator
    case other

    var title: String {
        switch self {
        case .delay: return "Delay"
        case .suspension: return "Suspension"
        case .plannedWork: return "Planned work"
        case .elevator: return "Elevator or escalator"
        case .other: return "Notice"
        }
    }

    var symbolName: String {
        switch self {
        case .delay: return "hourglass"
        case .suspension: return "xmark.octagon.fill"
        case .plannedWork: return "wrench.and.screwdriver.fill"
        case .elevator: return "figure.stairs"
        case .other: return "megaphone.fill"
        }
    }
}

/// One message PATH sent about an issue.
struct IssueUpdate: Codable, Hashable, Identifiable, Sendable {
    var id: Int
    var date: Date
    var subject: String
    var message: String
}

/// A PATH alert thread (one incident and its updates), or a delay the app noticed itself
/// by comparing live arrivals with the timetable.
struct Issue: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var kind: IssueKind
    var title: String
    /// Oldest first.
    var updates: [IssueUpdate]
    var startedAt: Date
    /// `nil` while the issue is still open.
    var endedAt: Date?
    /// Line codes ("JSQ-33") the latest update reports as delayed or suspended.
    var affectedLines: [String] = []
    /// True when the app detected this from live arrivals, not from a PATH alert.
    var detected = false

    var isActive: Bool { endedAt == nil }
    var latestMessage: String { updates.last?.message ?? "" }

    /// Whether this issue slows or stops trains from `origin` towards `target`.
    func affects(from origin: Station, to target: Station) -> Bool {
        affectedLines.contains { code in
            guard let stations = PathLines.stations[code] else { return false }
            return stations.contains(origin) && stations.contains(target)
        }
    }
}

enum PathLines {
    /// The line codes PATH uses in its alerts.
    static let stations: [String: [Station]] = [
        "NWK-WTC": [.newark, .harrison, .journalSquare, .groveStreet, .exchangePlace, .worldTradeCenter],
        "JSQ-33": [.journalSquare, .groveStreet, .newport, .hoboken, .christopherStreet, .ninthStreet,
                   .fourteenthStreet, .twentyThirdStreet, .thirtyThirdStreet],
        "HOB-33": [.hoboken, .christopherStreet, .ninthStreet, .fourteenthStreet, .twentyThirdStreet, .thirtyThirdStreet],
        "HOB-WTC": [.hoboken, .newport, .exchangePlace, .worldTradeCenter],
    ]

    /// Codes named in the sentences of `message` that report a delay or suspension.
    static func affected(in message: String) -> [String] {
        var found: [String] = []
        for sentence in message.components(separatedBy: ". ") {
            let lowered = sentence.lowercased()
            guard lowered.contains("delay") || lowered.contains("suspend") else { continue }
            let upper = sentence.uppercased()
            for code in stations.keys.sorted() where upper.contains(code) && !found.contains(code) {
                found.append(code)
            }
        }
        return found
    }
}

/// One entry from the Port Authority alert feed.
struct PathAlert: Decodable, Sendable {
    let messageID: Int
    /// Shared by every update about the same incident.
    let incidentID: String
    let subject: String
    let message: String
    let template: String
    let isOpen: Bool
    let sent: Date

    private enum CodingKeys: String, CodingKey {
        case messageid, ebid, Subject, SentMessage, TemplateName, state, sentdate2
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageID = try container.decode(Int.self, forKey: .messageid)
        if let number = try? container.decode(Int.self, forKey: .ebid) {
            incidentID = String(number)
        } else {
            incidentID = try container.decode(String.self, forKey: .ebid)
        }
        subject = (try? container.decode(String.self, forKey: .Subject)) ?? ""
        message = (try? container.decode(String.self, forKey: .SentMessage)) ?? ""
        template = (try? container.decode(String.self, forKey: .TemplateName)) ?? ""
        isOpen = ((try? container.decode(String.self, forKey: .state)) ?? "").lowercased() == "open"
        // "/Date(1795306769581)/": milliseconds since 1970.
        let stamp = try container.decode(String.self, forKey: .sentdate2)
        guard let milliseconds = Double(stamp.filter(\.isNumber)) else {
            throw DecodingError.dataCorruptedError(forKey: .sentdate2, in: container, debugDescription: stamp)
        }
        sent = Date(timeIntervalSince1970: milliseconds / 1000)
    }
}

enum PathAlertFeed {
    static let url = URL(string: "https://www.panynj.gov/bin/portauthority/alerts")!

    /// `nil` on any failure, so a network error is never mistaken for "all clear".
    static func fetch(timeout: TimeInterval = 6) async -> [PathAlert]? {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode([PathAlert].self, from: data)
    }
}

/// Every issue the app has seen. Open ones show on the home screen; ended ones are the archive.
struct IssueLog: Codable, Sendable {
    static let fileName = "issues.json"
    /// Archived issues older than this are dropped.
    static let retention: TimeInterval = 400 * 24 * 60 * 60

    var issues: [Issue] = []

    var active: [Issue] {
        issues.filter(\.isActive).sorted { $0.startedAt > $1.startedAt }
    }

    /// Most recently ended first.
    var archived: [Issue] {
        issues.filter { !$0.isActive }.sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
    }

    static func load() -> IssueLog {
        SharedStore.read(IssueLog.self, from: fileName) ?? IssueLog()
    }

    func save() {
        SharedStore.write(self, to: IssueLog.fileName)
    }

    /// Brings the log in line with the alert feed. The feed lists recent closed incidents
    /// too, so ones the app never saw open still land in the archive with PATH's own times.
    mutating func merge(alerts: [PathAlert], now: Date) {
        let threads = Dictionary(grouping: alerts, by: \.incidentID)
        for (incidentID, unsorted) in threads {
            let messages = unsorted.sorted { $0.sent < $1.sent }
            guard let first = messages.first, let last = messages.last else { continue }
            let kind = IssueLog.kind(of: messages)
            let isOpen = messages.contains(where: \.isOpen)
            let issue = Issue(
                id: incidentID,
                kind: kind,
                title: IssueLog.title(of: first, kind: kind),
                updates: messages.map { IssueUpdate(id: $0.messageID, date: $0.sent, subject: $0.subject, message: $0.message) },
                startedAt: first.sent,
                endedAt: isOpen ? nil : last.sent,
                affectedLines: isOpen ? PathLines.affected(in: last.message) : []
            )
            if let index = issues.firstIndex(where: { $0.id == incidentID }) {
                issues[index] = issue
            } else {
                issues.append(issue)
            }
        }
        // An open alert that has dropped out of the feed is over; the best end time is now.
        for index in issues.indices where issues[index].isActive && !issues[index].detected && threads[issues[index].id] == nil {
            issues[index].endedAt = now
            issues[index].affectedLines = []
        }
        prune(now: now)
    }

    /// Records delays seen in live arrivals. `delays` holds every line currently running
    /// at least `BoardPlan.majorDelay` behind; lines no longer listed are closed.
    mutating func noteDetectedDelays(_ delays: [(origin: Station, target: Station, minutes: Int)], at origin: Station, now: Date) {
        for delay in delays {
            let key = "live-\(delay.origin.rawValue)-\(delay.target.rawValue)"
            let update = IssueUpdate(
                id: Int(now.timeIntervalSince1970),
                date: now,
                subject: "Running late",
                message: "Live arrivals from \(delay.origin.name) to \(delay.target.name) are about \(delay.minutes) min behind the timetable."
            )
            if let index = issues.firstIndex(where: { $0.isActive && $0.detected && $0.id.hasPrefix(key) }) {
                issues[index].updates.append(update)
            } else {
                issues.append(Issue(
                    id: "\(key)-\(Int(now.timeIntervalSince1970))",
                    kind: .delay,
                    title: "\(delay.origin.shortName) to \(delay.target.shortName) running late",
                    updates: [update],
                    startedAt: now,
                    detected: true
                ))
            }
        }
        // Only this station's lines were checked, so only they can be closed.
        let prefix = "live-\(origin.rawValue)-"
        for index in issues.indices where issues[index].isActive && issues[index].detected && issues[index].id.hasPrefix(prefix) {
            let stillLate = delays.contains { issues[index].id.hasPrefix("live-\($0.origin.rawValue)-\($0.target.rawValue)-") }
            if !stillLate { issues[index].endedAt = now }
        }
    }

    private mutating func prune(now: Date) {
        issues.removeAll { issue in
            guard let ended = issue.endedAt else { return false }
            return now.timeIntervalSince(ended) > IssueLog.retention
        }
    }

    private static func kind(of messages: [PathAlert]) -> IssueKind {
        let text = messages.map { "\($0.template) \($0.subject) \($0.message)" }.joined(separator: " ").lowercased()
        if text.contains("elevator") || text.contains("escalator") { return .elevator }
        if text.contains("planned") { return .plannedWork }
        if text.contains("suspend") { return .suspension }
        if text.contains("delay") { return .delay }
        return .other
    }

    private static func title(of first: PathAlert, kind: IssueKind) -> String {
        let prefix = "PATH - "
        if kind != .elevator, kind != .plannedWork, first.template.hasPrefix(prefix) {
            return String(first.template.dropFirst(prefix.count))
        }
        return first.subject.isEmpty ? kind.title : first.subject
    }
}
