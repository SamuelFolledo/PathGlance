import SwiftUI

/// Every train from one station towards one destination, from now to the end of tomorrow.
struct DeparturesView: View {
    let route: LineRoute

    @EnvironmentObject private var model: AppModel
    @State private var arrivals: [RealtimeArrival] = []
    @State private var now = Date()

    private struct Day: Identifiable {
        var id: Int
        var title: String
        var note: String?
        var trains: [TrainTime]
    }

    private var group: BoardPlan.Group? {
        guard let schedule = model.schedule else { return nil }
        var plan = BoardPlan(station: route.origin, targets: [route.target], schedule: schedule, now: now, limit: 600)
        plan.apply(realtime: arrivals, now: now)
        plan.apply(issues: model.issues.active, includePlannedWork: false)
        return plan.groups.first
    }

    private func days(_ trains: [TrainTime]) -> [Day] {
        let calendar = PathTime.calendar
        let today = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 2, to: today) else { return [] }
        let log = DayTypeLog.load()
        let grouped = Dictionary(grouping: trains.filter { $0.time < end }) { PathTime.ymd(of: $0.time) }
        return grouped.keys.sorted().map { ymd in
            let date = PathTime.date(fromYMD: ymd) ?? today
            let name = ymd == PathTime.ymd(of: today) ? "Today" : "Tomorrow"
            return Day(
                id: ymd,
                title: "\(name) · \(PathFormat.day(date))",
                note: log.resolution(forYMD: ymd)?.note,
                trains: grouped[ymd] ?? []
            )
        }
    }

    var body: some View {
        List {
            if let group {
                let relevant = model.issues.active.filter { $0.affects(from: route.origin, to: route.target) }
                if group.delayMinutes > 0 || !relevant.isEmpty {
                    Section {
                        if group.delayMinutes > 0 {
                            Label("Next train is about \(group.delayMinutes) min behind the timetable", systemImage: IssueKind.delay.symbolName)
                                .foregroundStyle(.yellow)
                        }
                        ForEach(relevant) { issue in
                            IssueRow(issue: issue)
                        }
                    }
                }
                let sections = days(group.trains)
                if sections.isEmpty {
                    Text("No trains before the end of tomorrow.")
                        .foregroundStyle(.secondary)
                }
                ForEach(sections) { day in
                    Section {
                        ForEach(day.trains, id: \.self) { train in
                            HStack {
                                Text(CompactTimes.clockWithPeriod(train.time))
                                    .monospacedDigit()
                                Spacer()
                                if train.isLive {
                                    Text(group.delay == .none ? "Live" : "Live · late")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(group.delay == .none ? .green : .yellow)
                                }
                            }
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.title)
                            if let note = day.note {
                                Label(note, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .textCase(nil)
                            }
                        }
                    }
                }
            } else {
                Text("Download the schedule first.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("\(route.origin.shortName) to \(route.target.name)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: route) {
            now = Date()
            if model.useRealtime {
                arrivals = await RealtimeFeed.fetch()
            }
        }
        .refreshable {
            now = Date()
            if model.useRealtime {
                arrivals = await RealtimeFeed.fetch()
            }
            await model.refreshIssues()
        }
    }
}
