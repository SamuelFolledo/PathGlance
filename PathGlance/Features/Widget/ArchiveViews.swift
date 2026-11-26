import SwiftUI

/// Each distinct timetable downloaded from PATH's website.
struct TimetableArchiveView: View {
    @State private var entries: [TimetableArchive.Entry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entries.isEmpty {
                Text("No timetable downloaded yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.label)
                        .font(.subheadline.weight(.semibold))
                    Text("In use \(PathFormat.dayWithYear(entry.firstSeen)) – \(PathFormat.dayWithYear(entry.lastSeen))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(entry.departureCount) station departures a week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                Divider()
            }
        }
        .onAppear { entries = TimetableArchive.entries() }
    }
}

/// What live arrivals have shown about which timetable ran on which day. This is how a
/// holiday is recognised, and what next year's holiday starts from.
struct DayTypeLogView: View {
    @State private var log = DayTypeLog()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if log.observations.isEmpty {
                Text("Nothing recorded yet. Days appear here once the widget has seen live arrivals.")
                    .foregroundStyle(.secondary)
            }
            ForEach(log.observations, id: \.ymd) { day in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(PathTime.date(fromYMD: day.ymd).map(PathFormat.dayWithYear) ?? "\(day.ymd)")
                            .font(.subheadline.weight(.semibold))
                        if let holiday = Holiday.on(ymd: day.ymd) {
                            Text(holiday.name)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(summary(day))
                        .font(.caption)
                        .foregroundStyle(day.matched == DayType.normal(forYMD: day.ymd) || day.matched == nil ? Color.secondary : Color.orange)
                    Text(DayType.allCases.map { "\($0.name) \(String(format: "%.1f", day.meanError($0)))" }.joined(separator: " · ") + " min off, \(day.samples) arrivals")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                Divider()
            }
        }
        .infoPopover("Learned day types",
                     "Each day's live arrivals are compared with the weekday, Saturday and Sunday timetables.",
                     "The closest one is taken as the timetable PATH ran that day.",
                     "That is how a holiday is recognised, and what next year's holiday starts from.")
        .onAppear { log = DayTypeLog.load() }
    }

    private func summary(_ day: DayObservation) -> String {
        guard let matched = day.matched else { return "Not enough live data to tell" }
        let normal = DayType.normal(forYMD: day.ymd)
        return matched == normal ? "Ran the \(matched.name) timetable as expected" : "Ran the \(matched.name) timetable instead of \(normal.name)"
    }
}
