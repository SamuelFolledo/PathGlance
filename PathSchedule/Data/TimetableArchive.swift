import Foundation
import CryptoKit

/// Every distinct timetable the app has downloaded, kept so the history can be viewed
/// and an older one is still on the phone if PATH's page ever becomes unreadable.
enum TimetableArchive {
    struct Entry: Codable, Identifiable, Hashable {
        /// Fingerprint of the train times, so a re-download of the same timetable is not a new entry.
        var id: String
        /// PATH's own label, such as "Effective November 16, 2026".
        var label: String
        var firstSeen: Date
        var lastSeen: Date
        /// Station departures across the weekday, Saturday and Sunday timetables.
        var departureCount: Int
    }

    private static let indexName = "timetables/index.json"

    /// Newest first.
    static func entries() -> [Entry] {
        (SharedStore.read([Entry].self, from: indexName) ?? []).sorted { $0.lastSeen > $1.lastSeen }
    }

    static func schedule(for entry: Entry) -> ScheduleData? {
        SharedStore.read(ScheduleData.self, from: "timetables/\(entry.id).json")
    }

    static func record(_ schedule: ScheduleData) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let content = try? encoder.encode(schedule.departures) else { return }
        let id = SHA256.hash(data: content).prefix(8).map { String(format: "%02x", $0) }.joined()

        var all = SharedStore.read([Entry].self, from: indexName) ?? []
        if let index = all.firstIndex(where: { $0.id == id }) {
            all[index].lastSeen = schedule.importedAt
        } else {
            all.append(Entry(
                id: id,
                label: schedule.feedVersion ?? "Timetable",
                firstSeen: schedule.importedAt,
                lastSeen: schedule.importedAt,
                departureCount: schedule.departures.values.reduce(0) { $0 + $1.count }
            ))
            SharedStore.write(schedule, to: "timetables/\(id).json")
        }
        SharedStore.write(all, to: indexName)
    }
}
