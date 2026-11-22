import SwiftUI

/// The home tab: the lock screen preview, then every train from one station towards one
/// destination on one day. The station, destination and day can all be changed.
struct TrainsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService

    @State private var arrivals: [RealtimeArrival] = []
    @State private var now = Date()
    @State private var dayTypes = DayTypeLog()
    @State private var showingLockScreenSettings = false

    private static let dayRange = -7...14
    private static let terminals: [Station] = [.thirtyThirdStreet, .worldTradeCenter, .journalSquare, .hoboken, .newark]

    /// The station the widget shows: pinned, else nearest.
    private var widgetStation: Station {
        model.manualStation ?? location.station ?? .journalSquare
    }

    private var origin: Station {
        model.browseOrigin ?? widgetStation
    }

    /// Segments: the widget's lines first, then the other ends of the lines that call here,
    /// then any other stop picked from the menu.
    private func destinations(_ schedule: ScheduleData) -> [Station] {
        var result = BoardRules.widgetTargets(from: origin, favorites: model.favoriteTargets, schedule: schedule)
        for station in TrainsView.terminals + [model.browseTarget].compactMap({ $0 })
        where !result.contains(station) && schedule.reaches(from: origin, to: station) {
            result.append(station)
        }
        return result
    }

    private func target(in destinations: [Station]) -> Station? {
        if let chosen = model.browseTarget, destinations.contains(chosen) { return chosen }
        return destinations.first
    }

    private var viewedDay: Date {
        let today = PathTime.calendar.startOfDay(for: now)
        return PathTime.calendar.date(byAdding: .day, value: model.dayOffset, to: today) ?? today
    }

    private struct Listing {
        var trains: [TrainTime] = []
        var delay: DelayLevel = .none
        var delayMinutes = 0
    }

    /// Today lists what is still to come, with live times. Other days list the whole day.
    private func listing(_ schedule: ScheduleData, to target: Station) -> Listing {
        let ymd = PathTime.ymd(of: viewedDay)
        if model.dayOffset == 0 {
            var plan = BoardPlan(station: origin, targets: [target], schedule: schedule, now: now, limit: 600)
            plan.apply(realtime: arrivals, now: now)
            plan.apply(issues: model.issues.active, includePlannedWork: false)
            guard let group = plan.groups.first else { return Listing() }
            return Listing(trains: group.trains.filter { PathTime.ymd(of: $0.time) == ymd }, delay: group.delay, delayMinutes: group.delayMinutes)
        }
        var other = schedule
        other.dayOverrides = dayTypes.overrides(around: viewedDay)
        let trains = other.departures(from: origin, to: target, after: viewedDay.addingTimeInterval(-1), limit: 1000)
        return Listing(trains: trains.filter { PathTime.ymd(of: $0.time) == ymd })
    }

    var body: some View {
        NavigationStack {
            List {
                if let schedule = model.schedule {
                    let destinations = destinations(schedule)
                    let target = target(in: destinations)
                    Section {
                        previewCard(schedule)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    Section {
                        destinationPicker(destinations, selected: target, schedule: schedule)
                        dayRow
                    }
                    .listRowSeparator(.hidden)
                    if let target {
                        trainSections(schedule, target: target)
                    }
                } else {
                    Section {
                        Text(model.isImporting ? "Downloading the timetable…" : "No timetable yet.")
                            .foregroundStyle(.secondary)
                        if let error = model.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        Button("Download timetable") {
                            Task { await model.downloadSchedule() }
                        }
                        .disabled(model.isImporting)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    originMenu
                }
            }
            // A sideways swipe moves between destinations.
            .simultaneousGesture(
                DragGesture(minimumDistance: 40).onEnded { drag in
                    guard abs(drag.translation.width) > 80, abs(drag.translation.width) > abs(drag.translation.height) * 2 else { return }
                    stepDestination(by: drag.translation.width < 0 ? 1 : -1)
                }
            )
            .refreshable {
                await reload()
                await model.refreshIssues()
            }
            .task(id: origin) {
                await reload()
            }
            .sheet(isPresented: $showingLockScreenSettings) {
                NavigationStack {
                    List {
                        LockScreenSettings()
                    }
                    .navigationTitle("Lock screen")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingLockScreenSettings = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func reload() async {
        now = Date()
        dayTypes = DayTypeLog.load()
        if model.useRealtime {
            arrivals = await RealtimeFeed.fetch()
        }
    }

    private func stepDestination(by step: Int) {
        guard let schedule = model.schedule else { return }
        let all = destinations(schedule)
        guard let current = target(in: all), let index = all.firstIndex(of: current),
              all.indices.contains(index + step) else { return }
        withAnimation { model.browseTarget = all[index + step] }
    }

    // MARK: Pieces

    /// Station name in the title bar; tap to board somewhere else.
    private var originMenu: some View {
        Menu {
            Button {
                model.browseOrigin = nil
            } label: {
                Label("\(widgetStation.name) (\(model.manualStation == nil ? "nearest" : "pinned"))",
                      systemImage: model.browseOrigin == nil ? "checkmark" : "location")
            }
            Divider()
            ForEach(Station.allCases) { station in
                Button {
                    model.browseOrigin = station
                } label: {
                    if model.browseOrigin == station {
                        Label(station.name, systemImage: "checkmark")
                    } else {
                        Text(station.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("From \(origin.name)")
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.primary)
        }
    }

    /// What the lock screen widget shows right now. Tap for its settings.
    private func previewCard(_ schedule: ScheduleData) -> some View {
        let station = widgetStation
        let targets = BoardRules.widgetTargets(from: station, favorites: model.favoriteTargets, schedule: schedule)
        var plan = BoardPlan(station: station, targets: targets, schedule: schedule, now: now)
        plan.showArrival = model.showArrivalOnWidget
        plan.apply(realtime: arrivals, now: now)
        plan.apply(issues: model.issues.active, includePlannedWork: model.plannedWorkOnLockScreen)
        let board = plan.board(at: now)

        return Button {
            showingLockScreenSettings = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("From \(station.shortName): \(CompactTimes.clockWithPeriod(now))")
                    Image(systemName: "arrow.clockwise")
                    if board.hasAlert {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    Spacer()
                    Text("Lock screen")
                        .foregroundStyle(.secondary)
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.secondary)
                }
                .font(model.fontStyle.font(size: 12))
                if board.lines.isEmpty {
                    Text("No upcoming trains")
                }
                ForEach(board.lines, id: \.self) { line in
                    Text(line.text)
                }
            }
            .font(model.fontStyle.font(size: 18))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func destinationPicker(_ destinations: [Station], selected: Station?, schedule: ScheduleData) -> some View {
        HStack(spacing: 8) {
            Picker("Destination", selection: Binding(
                get: { selected ?? origin },
                set: { model.browseTarget = $0 }
            )) {
                ForEach(destinations) { station in
                    Text(station.lineLabel).tag(station)
                }
            }
            .pickerStyle(.segmented)

            // Any other stop a train from here reaches.
            Menu {
                ForEach(Station.allCases.filter { schedule.reaches(from: origin, to: $0) && !destinations.contains($0) }) { station in
                    Button(station.name) { model.browseTarget = station }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var dayRow: some View {
        HStack {
            Button {
                model.dayOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(model.dayOffset <= TrainsView.dayRange.lowerBound)

            Spacer()
            Button {
                model.dayOffset = 0
            } label: {
                VStack(spacing: 0) {
                    Text(dayTitle)
                        .font(.subheadline.weight(.semibold))
                    if let holiday = Holiday.on(ymd: PathTime.ymd(of: viewedDay)) {
                        Text(holiday.name)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()

            Button {
                model.dayOffset += 1
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(model.dayOffset >= TrainsView.dayRange.upperBound)
        }
        .buttonStyle(.glass)
    }

    private var dayTitle: String {
        let date = PathFormat.day(viewedDay)
        switch model.dayOffset {
        case 0: return "Today · \(date)"
        case 1: return "Tomorrow · \(date)"
        case -1: return "Yesterday · \(date)"
        default: return date
        }
    }

    @ViewBuilder
    private func trainSections(_ schedule: ScheduleData, target: Station) -> some View {
        let listing = listing(schedule, to: target)
        let relevant = model.dayOffset == 0 ? model.issues.active.filter { $0.affects(from: origin, to: target) } : []
        let note = dayTypes.resolution(forYMD: PathTime.ymd(of: viewedDay))?.note

        if listing.delayMinutes > 0 || !relevant.isEmpty {
            Section {
                if listing.delayMinutes > 0 {
                    Label("Next train is about \(listing.delayMinutes) min behind the timetable", systemImage: IssueKind.delay.symbolName)
                        .foregroundStyle(.yellow)
                }
                ForEach(relevant) { issue in
                    IssueRow(issue: issue)
                }
            }
        }

        Section {
            if listing.trains.isEmpty {
                Text(model.dayOffset == 0 ? "No more trains today." : "No trains on this day.")
                    .foregroundStyle(.secondary)
            }
            ForEach(listing.trains, id: \.self) { train in
                HStack {
                    Text(CompactTimes.clockWithPeriod(train.time))
                        .font(.body.weight(.medium))
                        .monospacedDigit()
                    if train.isLive {
                        Text(listing.delay == .none ? "Live" : "Live · late")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(listing.delay == .none ? .green : .yellow)
                    }
                    Spacer()
                    if let arrival = schedule.arrival(of: train, from: origin, to: target) {
                        Text("\(target.shortName) \(CompactTimes.clockWithPeriod(arrival))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Departs \(origin.shortName)")
                    Spacer()
                    Text("Arrives")
                }
                if let note {
                    Label(note, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textCase(nil)
                }
            }
        }
    }
}
