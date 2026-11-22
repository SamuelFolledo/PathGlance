import SwiftUI

/// The home tab: the station as the title, then one panel with destination tabs and the
/// date fixed on top and the trains scrolling beneath, day after day. Swiping sideways
/// turns to the next destination at the same time of the same day.
struct TrainsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService

    @State private var arrivals: [RealtimeArrival] = []
    @State private var now = Date()
    @State private var dayTypes = DayTypeLog()
    @State private var sheet: Sheet?
    @State private var datePicker: DatePick?
    /// The page the sideways scroll is on.
    @State private var page: Station?
    @State private var showsStations = false

    private enum Sheet: Identifiable {
        case favorites
        /// One train's stops, with the day's other trains to step through.
        case stops(TrainTime, target: Station, trains: [TrainTime])

        /// One id per kind: stepping to the next train changes the sheet's content in place.
        var id: String {
            switch self {
            case .favorites: return "favorites"
            case .stops: return "stops"
            }
        }
    }

    private struct DatePick: Identifiable {
        let id = "date"
    }

    private var origin: Station {
        model.station(nearest: location.station)
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
            title
            if let schedule = model.schedule {
                panel(schedule)
            } else {
                emptyState
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .bottomTrailing) {
            if isAway {
                Button {
                    model.jump(to: Date())
                } label: {
                    Label("Now", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 6)
                        .frame(height: 36)
                }
                .buttonStyle(.glass)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
                .accessibilityLabel("Back to now")
                .accessibilityIdentifier("backToNow")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.snappy, value: isAway)
        .appSheet(item: $sheet, title: sheetTitle, subtitle: sheetSubtitle) { sheet in
            switch sheet {
            case .favorites:
                FavoriteStopsView()
            case .stops(let train, let target, let trains):
                if let schedule = model.schedule {
                    StopsView(schedule: schedule, origin: origin, target: target, train: train, trains: trains, now: now) { other in
                        self.sheet = .stops(other, target: target, trains: trains)
                    }
                }
            }
        }
        .appSheet(item: $datePicker, style: .popup, title: { _ in "Go to date" }) { _ in
            DateJumpView(now: now, viewing: model.listAnchor) { date in
                datePicker = nil
                model.jump(to: date)
            }
        }
        .task(id: origin) {
            await reload()
        }
        .task {
            // Keep "now" and the live times fresh while the app is open.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await reload()
            }
        }
        .onChange(of: model.resetCount[.trains]) {
            sheet = nil
            datePicker = nil
        }
        .onChange(of: model.favoritesRequests) {
            datePicker = nil
            sheet = .favorites
        }
    }

    /// "Today · J Sq to 33rd": the day, then where from and to. The time is in the sheet,
    /// between the arrows, since that is what changes from train to train.
    private func sheetTitle(_ sheet: Sheet) -> String {
        switch sheet {
        case .favorites: return "Favorite stops"
        case .stops(let train, let target, _): return "\(PathFormat.relativeDay(train.time, now: now)) · \(origin.shortName) to \(target.shortName)"
        }
    }

    private func sheetSubtitle(_ sheet: Sheet) -> String? {
        switch sheet {
        case .favorites: return "Each checked stop gets a column of arrival times in the train list."
        case .stops: return nil
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

    /// "From Journal Square", centered. Tap for the station list and favorite stops.
    private var title: some View {
        Button {
            showsStations.toggle()
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Text("From \(origin.name)")
                    .font(.title3.weight(.bold))
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.bold))
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsStations) {
            StationMenu(isShowing: $showsStations)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("From \(origin.name). Change station")
        .accessibilityIdentifier("originMenu")
        .padding(.horizontal, Theme.Spacing.contentSide)
        .padding(.top, Theme.Spacing.sm)
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
                                      onSelectTrain: { train, trains in sheet = .stops(train, target: target, trains: trains) },
                                      onPickDate: { datePicker = DatePick() },
                                      onRefresh: {
                                          await reload()
                                          await model.refreshIssues()
                                      })
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
                // A widget line was tapped.
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
        .clipShape(.rect(topLeadingRadius: Theme.Radius.card, topTrailingRadius: Theme.Radius.card))
        .padding(.horizontal, Theme.Spacing.contentSide)
        .ignoresSafeArea(edges: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if model.isImporting {
                ProgressView("Downloading the timetable")
            } else {
                Text("No timetable yet.")
                    .foregroundStyle(.secondary)
            }
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

/// Every stop one train makes, with its arrival time. The arrows, or a sideways swipe that
/// follows the finger, turn to the train before or after it.
struct StopsView: View {
    let schedule: ScheduleData
    let origin: Station
    let target: Station
    let train: TrainTime
    /// The list this train came from, in order.
    let trains: [TrainTime]
    let now: Date
    let show: (TrainTime) -> Void

    @EnvironmentObject private var model: AppModel
    /// The page the sideways scroll is on: a train's time.
    @State private var page: Double?

    private var index: Int? { trains.firstIndex(of: train) }

    private func id(_ train: TrainTime) -> Double { train.time.timeIntervalSince1970 }

    private func step(_ offset: Int) {
        guard let index, trains.indices.contains(index + offset) else { return }
        show(trains[index + offset])
    }

    private func canStep(_ offset: Int) -> Bool {
        guard let index else { return false }
        return trains.indices.contains(index + offset)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Between the arrows: the one thing that changes from train to train.
            HStack {
                RoundButton(symbol: "chevron.left", label: "Earlier train", identifier: "earlierTrain") { step(-1) }
                    .disabled(!canStep(-1))
                Spacer()
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Text(CompactTimes.clockWithPeriod(train.time))
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        if train.isLive {
                            StatusDot(color: train.isLate ? .yellow : .green, label: train.isLate ? "Live, running late" : "Live")
                        }
                    }
                    let route = schedule.routeName(of: train, from: origin)
                    if !route.isEmpty {
                        Text("To \(route)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("stopsTime")
                Spacer()
                RoundButton(symbol: "chevron.right", label: "Later train", identifier: "laterTrain") { step(1) }
                    .disabled(!canStep(1))
            }
            .animation(Theme.Motion.content, value: train)

            // A sideways scroll of lazy pages guesses its own height and can come out short,
            // cutting off the last stop, so the height is taken from this train's own page.
            StopsPage(schedule: schedule, origin: origin, target: target, train: train, hasLeft: hasLeft(train))
                .hidden()
                .accessibilityHidden(true)
                .overlay(alignment: .top) { pager }
        }
    }

    private func hasLeft(_ train: TrainTime) -> Bool {
        !train.isLive && train.time <= now.addingTimeInterval(-BoardPlan.grace)
    }

    /// One page per train. The page follows the finger and the next train slides in.
    private var pager: some View {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 0) {
                    ForEach(trains, id: \.time) { other in
                        StopsPage(schedule: schedule, origin: origin, target: target, train: other,
                                  hasLeft: hasLeft(other))
                            .containerRelativeFrame(.horizontal)
                            .id(id(other))
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                // Once the swipe has come to rest, the sheet is about that train.
                if phase == .idle, let page, page != id(train), let landed = trains.first(where: { id($0) == page }) {
                    show(landed)
                }
            }
            .onChange(of: train) { _, new in
                if page != id(new) {
                    withAnimation(Theme.Motion.content) { page = id(new) }
                }
            }
            .onAppear { page = id(train) }
    }
}

/// One train's stops: a banner if it is running late, then every stop.
private struct StopsPage: View {
    let schedule: ScheduleData
    let origin: Station
    let target: Station
    let train: TrainTime
    /// Already gone: shown a little greyed.
    let hasLeft: Bool

    @EnvironmentObject private var model: AppModel

    var body: some View {
        let stops = schedule.stops(of: train, from: origin)
        let delay = TimeInterval(train.isLate ? train.delayMinutes * 60 : 0)
        VStack(alignment: .leading, spacing: 0) {
            if train.isLate {
                Label("Running \(TrainTime.delayText(train.delayMinutes)) late. Later stops are moved by the same amount.",
                      systemImage: IssueKind.delay.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.yellow.opacity(0.14), in: .rect(cornerRadius: 12))
                    .padding(.bottom, Theme.Spacing.sm)
                    .accessibilityIdentifier("delayBanner")
            } else if hasLeft {
                Text("This train has left.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Theme.Spacing.sm)
            }
            row(name: origin.name, time: train.time, lateBy: delay, isFavorite: false, isEnd: true)
            ForEach(stops, id: \.station) { stop in
                row(name: stop.station.name, time: stop.time, lateBy: delay,
                    isFavorite: model.favoriteStops.contains(stop.station), isEnd: stop.station == target)
                    .contextMenu {
                        Button {
                            model.toggleFavorite(stop.station)
                        } label: {
                            Label(model.favoriteStops.contains(stop.station) ? "Unfavorite \(stop.station.name)" : "Favorite \(stop.station.name)",
                                  systemImage: model.favoriteStops.contains(stop.station) ? "star.slash" : "star")
                        }
                        Button {
                            model.showsPeriod.toggle()
                        } label: {
                            Label(model.showsPeriod ? "Hide AM and PM" : "Show AM and PM", systemImage: "clock")
                        }
                    }
            }
            if stops.isEmpty {
                Text("Stop times are not available for this train.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, Theme.Spacing.sm)
            }
        }
        .opacity(hasLeft ? 0.55 : 1)
    }

    private func row(name: String, time: Date, lateBy: TimeInterval, isFavorite: Bool, isEnd: Bool) -> some View {
        HStack {
            Text(name)
                .fontWeight(isEnd ? .semibold : .regular)
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }
            Spacer()
            if lateBy > 0 {
                Text(model.clock(time.addingTimeInterval(-lateBy)))
                    .strikethrough()
                    .foregroundStyle(.yellow.opacity(0.7))
                Text(model.clock(time))
                    .fontWeight(.semibold)
                    .foregroundStyle(.yellow)
            } else {
                Text(model.clock(time))
                    .foregroundStyle(isEnd ? .primary : .secondary)
            }
        }
        .monospacedDigit()
        .padding(.vertical, Theme.Spacing.row)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
    }
}

/// A month calendar for jumping the list to another day. It opens on the day being
/// viewed, which is highlighted; today keeps its own mark.
struct DateJumpView: View {
    let now: Date
    let onPick: (Date) -> Void

    @State private var date: Date

    init(now: Date, viewing: Date, onPick: @escaping (Date) -> Void) {
        self.now = now
        self.onPick = onPick
        _date = State(initialValue: viewing)
    }

    private var range: ClosedRange<Date> {
        let calendar = PathTime.calendar
        let today = calendar.startOfDay(for: now)
        let first = calendar.date(byAdding: .day, value: -AppModel.daysBack, to: today) ?? today
        let last = calendar.date(byAdding: .day, value: AppModel.daysAhead + 1, to: today)?.addingTimeInterval(-1) ?? today
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
            Button {
                onPick(Date())
            } label: {
                Label("Back to now", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.glass)
        }
    }
}
