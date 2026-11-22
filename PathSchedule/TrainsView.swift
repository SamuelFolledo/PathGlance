import SwiftUI

/// The home tab. At the top, the station and a preview of the lock screen widget. Below,
/// one panel: destination tabs and the date stay pinned while the trains scroll under
/// them, day after day. Swiping sideways turns to the next destination at the same time
/// of the same day.
struct TrainsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var arrivals: [RealtimeArrival] = []
    @State private var now = Date()
    @State private var dayTypes = DayTypeLog()
    @State private var sheet: Sheet?
    @State private var datePicker: DatePick?
    /// The page the sideways scroll is on.
    @State private var page: Station?

    private enum Sheet: Identifiable {
        case lockScreen
        case favorites
        case stops(TrainTime, target: Station)

        var id: String {
            switch self {
            case .lockScreen: return "lockScreen"
            case .favorites: return "favorites"
            case .stops(let train, let target): return "stops-\(train.time.timeIntervalSince1970)-\(target.rawValue)"
            }
        }
    }

    private struct DatePick: Identifiable {
        let id = "date"
    }

    /// The station the widget shows: pinned, else nearest.
    private var widgetStation: Station {
        model.manualStation ?? location.station ?? .journalSquare
    }

    private var origin: Station {
        model.browseOrigin ?? widgetStation
    }

    private func destinations(_ schedule: ScheduleData) -> [Station] {
        BoardRules.destinations(from: origin, hidden: model.hiddenTargets, schedule: schedule)
    }

    private func selected(in destinations: [Station]) -> Station? {
        if let chosen = model.browseTarget, destinations.contains(chosen) { return chosen }
        return destinations.first
    }

    /// Scrolled well away from the present: time to offer a way back.
    private var isAway: Bool {
        abs(model.listAnchor.timeIntervalSince(now)) > 3 * 60 * 60
    }

    var body: some View {
        VStack(spacing: 8) {
            topBar
            if let schedule = model.schedule {
                // The preview makes way once the list is scrolled off, and on a phone held sideways.
                if verticalSizeClass != .compact && !isAway {
                    previewCard(schedule)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                panel(schedule)
            } else {
                emptyState
            }
        }
        .animation(.snappy, value: isAway)
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .bottomTrailing) {
            if isAway {
                Button {
                    model.jump(to: Date())
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
                .accessibilityLabel("Back to now")
                .accessibilityIdentifier("backToNow")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .appSheet(item: $sheet, title: sheetTitle) { sheet in
            switch sheet {
            case .lockScreen:
                LockScreenOptionsView()
            case .favorites:
                FavoriteStopsView()
            case .stops(let train, let target):
                if let schedule = model.schedule {
                    StopsView(schedule: schedule, origin: origin, target: target, train: train)
                }
            }
        }
        .appSheet(item: $datePicker, style: .popup, title: { _ in "Go to date" }) { _ in
            DateJumpView(now: now) { date in
                datePicker = nil
                model.jump(to: date)
            }
        }
        .task(id: origin) {
            await reload()
        }
        .task {
            // Keep "now" and the live times fresh while the tab is open.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await reload()
            }
        }
        .onChange(of: model.resetCount[.trains]) {
            sheet = nil
            datePicker = nil
        }
    }

    private func sheetTitle(_ sheet: Sheet) -> String {
        switch sheet {
        case .lockScreen: return "Lock screen widget"
        case .favorites: return "Favorite stops"
        case .stops(let train, _): return "\(CompactTimes.clockWithPeriod(train.time)) from \(origin.shortName)"
        }
    }

    private func reload() async {
        now = Date()
        dayTypes = DayTypeLog.load()
        if model.useRealtime {
            arrivals = await RealtimeFeed.fetch()
        }
    }

    // MARK: Pieces

    /// "From Journal Square" opens the station list; the star edits favorite stops.
    private var topBar: some View {
        HStack {
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
                        .font(.title3.weight(.bold))
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(.primary)
            }
            .accessibilityLabel("From \(origin.name). Change station")
            .accessibilityIdentifier("originMenu")
            Spacer()
            Button {
                sheet = .favorites
            } label: {
                Image(systemName: model.favoriteStops.isEmpty ? "star" : "star.fill")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Favorite stops")
            .accessibilityIdentifier("favoritesButton")
            .infoPopover("Favorite stops", "Each favorite stop gets a column of arrival times in the list.", "A stop only shows when trains to the chosen destination call there.")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// What the lock screen widget shows right now. The top row opens its options; a line
    /// turns the list to that destination.
    private func previewCard(_ schedule: ScheduleData) -> some View {
        let station = widgetStation
        var plan = BoardPlan(station: station, targets: BoardRules.widgetTargets(from: station, hidden: model.hiddenTargets),
                             schedule: schedule, now: now)
        plan.style = model.widgetStyle
        plan.apply(realtime: arrivals, now: now)
        plan.apply(issues: model.issues.active, includePlannedWork: model.plannedWorkOnLockScreen)
        let board = plan.board(at: now)

        return VStack(alignment: .leading, spacing: 4) {
            Button {
                sheet = .lockScreen
            } label: {
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
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Lock screen widget preview. Change how it looks")
            .accessibilityIdentifier("lockScreenPreview")
            BoardLinesView(board: board, font: model.fontStyle.font(size: model.widgetStyle.density == .compact ? 18 : 21)) { line in
                Button {
                    if let target = line.target { model.open(origin: station, target: target) }
                } label: {
                    Color.clear.contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .padding(.horizontal, 12)
        .infoPopover("Lock screen preview",
                     "This is what the widget shows right now.",
                     "Tap the top row to change its look.",
                     "Tap a line to list that destination's trains.",
                     "A ? after a line means a short delay, ! a long one.")
    }

    /// Destination tabs fixed at the top of one surface, the lists paging beneath.
    private func panel(_ schedule: ScheduleData) -> some View {
        let destinations = destinations(schedule)
        let current = selected(in: destinations)

        return VStack(spacing: 0) {
            Picker("Destination", selection: Binding(
                get: { current ?? origin },
                set: { target in
                    model.browseTarget = target
                    withAnimation(.snappy) { page = target }
                }
            )) {
                ForEach(destinations) { station in
                    Text(station.lineLabel)
                        .accessibilityLabel(station.name)
                        .tag(station)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .accessibilityIdentifier("destinationPicker")

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(destinations, id: \.self) { target in
                        TrainListPage(origin: origin, target: target, isSelected: target == current, now: now,
                                      arrivals: arrivals, dayTypes: dayTypes,
                                      onSelectTrain: { sheet = .stops($0, target: target) },
                                      onPickDate: { datePicker = DatePick() })
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                // Only once the swipe has come to rest: changing the selection while the
                // page is still moving stops it and it springs back.
                if phase == .idle, let page, page != current { model.browseTarget = page }
            }
            .onChange(of: model.browseTarget) { _, target in
                // A widget line or preview line was tapped.
                if let target, target != page { page = target }
            }
            .onChange(of: origin) {
                page = selected(in: self.destinations(schedule))
            }
            .onAppear {
                if page == nil { page = current }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
        .ignoresSafeArea(edges: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(model.isImporting ? "Downloading the timetable…" : "No timetable yet.")
                .foregroundStyle(.secondary)
            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button("Download timetable") {
                Task { await model.downloadSchedule() }
            }
            .buttonStyle(.glassProminent)
            .disabled(model.isImporting)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Every stop one train makes, with its arrival time.
struct StopsView: View {
    let schedule: ScheduleData
    let origin: Station
    let target: Station
    let train: TrainTime

    @EnvironmentObject private var model: AppModel

    var body: some View {
        let stops = schedule.stops(of: train, from: origin)
        VStack(alignment: .leading, spacing: 0) {
            Text(schedule.routeName(of: train, from: origin).isEmpty ? "" : "To \(schedule.routeName(of: train, from: origin))" + (train.isLive ? " · live departure" : ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            stopRow(name: origin.name, time: train.time, isFavorite: false, isEnd: false, isOrigin: true)
            ForEach(stops, id: \.station) { stop in
                stopRow(name: stop.station.name, time: stop.time,
                        isFavorite: model.favoriteStops.contains(stop.station),
                        isEnd: stop.station == target, isOrigin: false)
            }
            if stops.isEmpty {
                Text("Stop times are not available for this train.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }

    private func stopRow(name: String, time: Date, isFavorite: Bool, isEnd: Bool, isOrigin: Bool) -> some View {
        HStack {
            Image(systemName: isOrigin ? "circle.fill" : (isEnd ? "mappin.circle.fill" : "circle"))
                .font(.caption)
                .foregroundStyle(isOrigin || isEnd ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(name)
                .fontWeight(isOrigin || isEnd ? .semibold : .regular)
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }
            Spacer()
            Text(CompactTimes.clockWithPeriod(time))
                .monospacedDigit()
                .foregroundStyle(isOrigin || isEnd ? .primary : .secondary)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
    }
}

/// A month calendar for jumping the list to another day.
struct DateJumpView: View {
    let now: Date
    let onPick: (Date) -> Void

    @State private var date: Date

    init(now: Date, onPick: @escaping (Date) -> Void) {
        self.now = now
        self.onPick = onPick
        _date = State(initialValue: now)
    }

    private var range: ClosedRange<Date> {
        let calendar = PathTime.calendar
        let today = calendar.startOfDay(for: now)
        let first = calendar.date(byAdding: .day, value: -AppModel.daysBack, to: today) ?? today
        let last = calendar.date(byAdding: .day, value: AppModel.daysAhead, to: today) ?? today
        return first...last
    }

    var body: some View {
        VStack(spacing: 8) {
            DatePicker("Date", selection: $date, in: range, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.timeZone, PathTime.calendar.timeZone)
                .environment(\.calendar, PathTime.calendar)
                .onChange(of: date) { _, picked in
                    // Today lands on the next train; any other day on its first.
                    let isToday = PathTime.ymd(of: picked) == PathTime.ymd(of: now)
                    onPick(isToday ? Date() : PathTime.calendar.startOfDay(for: picked))
                }
            Button("Back to now") {
                onPick(Date())
            }
            .buttonStyle(.glass)
        }
    }
}
