import SwiftUI

extension IssueKind {
    /// Full color is for the app; the lock screen is monochrome.
    var color: Color {
        switch self {
        case .delay: return .yellow
        case .suspension: return .red
        case .plannedWork: return .orange
        case .elevator: return Theme.Colors.brand
        case .other: return .gray
        }
    }
}

enum PathFormat {
    private static func style() -> Date.FormatStyle {
        var style = Date.FormatStyle()
        style.timeZone = PathTime.calendar.timeZone
        return style
    }

    /// "Sat, Nov 21"
    static func day(_ date: Date) -> String {
        date.formatted(style().weekday(.abbreviated).month(.abbreviated).day())
    }

    /// "Today", "Tomorrow", "Yesterday", or "Sat, Nov 21".
    static func relativeDay(_ date: Date, now: Date) -> String {
        let calendar = PathTime.calendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        default: return day(date)
        }
    }

    /// "Sat, Nov 21, 2026"
    static func dayWithYear(_ date: Date) -> String {
        date.formatted(style().weekday(.abbreviated).month(.abbreviated).day().year())
    }

    /// "Nov 21, 4:12 PM"
    static func dayTime(_ date: Date) -> String {
        date.formatted(style().month(.abbreviated).day().hour().minute())
    }

    /// "4:12 PM – 6:13 PM", with the day added to the end when it differs.
    static func span(_ issue: Issue) -> String {
        let start = CompactTimes.clockWithPeriod(issue.startedAt)
        guard let end = issue.endedAt else { return "Since \(dayTime(issue.startedAt))" }
        if PathTime.ymd(of: issue.startedAt) == PathTime.ymd(of: end) {
            return "\(start) – \(CompactTimes.clockWithPeriod(end))"
        }
        return "\(dayTime(issue.startedAt)) – \(dayTime(end))"
    }
}

struct IssueRow: View {
    let issue: Issue
    /// One of the issues the tab's red badge is counting.
    var countsOnBadge = false
    /// Its kind is silenced: listed, but not counted and not on the widget.
    var isMuted = false
    let open: (Issue) -> Void

    var body: some View {
        Button {
            open(issue)
        } label: {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                Image(systemName: issue.kind.symbolName)
                    .font(.title3)
                    .foregroundStyle(issue.kind.color)
                    .frame(width: 28)
                    .accessibilityLabel(issue.kind.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text(PathFormat.span(issue))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !issue.latestMessage.isEmpty {
                        Text(issue.latestMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if isMuted {
                    Image(systemName: "bell.slash.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Muted")
                } else if countsOnBadge {
                    // The same red as the tab's badge: this is one of the issues it counts.
                    StatusDot(color: .red, label: "Counted on the Issues badge", mark: "!")
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows every update")
    }
}

extension PathLines {
    /// The colours PATH's map gives its lines.
    static func color(_ code: String) -> Color {
        switch code {
        case "NWK-WTC": return .red
        case "JSQ-33": return .orange
        case "HOB-33": return Theme.Colors.brand
        case "HOB-WTC": return .green
        default: return .gray
        }
    }
}

extension Issue {
    /// When PATH last said something about it: the time today, else the day too.
    func latestTime(now: Date) -> String {
        let date = updates.last?.date ?? startedAt
        return PathTime.ymd(of: date) == PathTime.ymd(of: now) ? CompactTimes.clockWithPeriod(date) : PathFormat.dayTime(date)
    }

    /// The issue as a banner: its title, PATH's latest words, and when they came.
    func banner(now: Date) -> IssueBannerItem {
        IssueBannerItem(id: id, symbol: kind.symbolName, color: kind.color, title: title,
                        subtitle: updates.last?.body ?? "",
                        time: latestTime(now: now))
    }

    /// Two made-up issues, for screenshots and UI tests.
    static func samples(now: Date) -> [Issue] {
        func update(_ id: Int, _ minutesAgo: Double, _ subject: String, _ message: String) -> IssueUpdate {
            IssueUpdate(id: id, date: now.addingTimeInterval(-minutesAgo * 60), subject: subject, message: message)
        }
        return [
            Issue(id: "sample-signal", kind: .delay, title: "Signal Problem",
                  updates: [update(1, 42, "PATHAlert: Signal Problem", "JSQ-33 delayed. Dispatch has reported a signal problem at Grove St."),
                            update(2, 30, "PATHAlert Update: Signal Problem", "JSQ-33 delayed up to 15 min. Maintenance dispatched."),
                            update(3, 17, "PATHAlert Update: Signal Problem", "JSQ-33 delayed up to 15 min. Crews on site, trains holding at Newport.")],
                  startedAt: now.addingTimeInterval(-42 * 60), affectedLines: ["JSQ-33"]),
            Issue(id: "sample-track", kind: .other, title: "Track Change",
                  updates: [update(4, 95, "PATHAlert: Track Change", "NWK-WTC trains are leaving from Harrison track H.")],
                  startedAt: now.addingTimeInterval(-95 * 60)),
        ]
    }
}

extension AppModel {
    /// Mutes or unmutes a kind of issue. Muting is explained first, since it hides things.
    /// Unmuting just happens, except for elevator notices, which start muted for a reason.
    func toggleMute(_ kind: IssueKind) {
        if mutedKinds.contains(kind) {
            guard kind == .elevator else {
                setMuted(kind, false)
                return
            }
            ask(Guide(
                id: "unmute-elevator",
                title: "Unmute elevator and escalator notices?",
                points: [
                    "PATH posts these often, and several are usually open at once.",
                    "Each will count on the Issues badge and put the alert mark on the lock screen widget.",
                ],
                confirm: "Unmute"
            ) { self.setMuted(kind, false) })
            return
        }
        ask(Guide(
            id: "mute-issues",
            title: "Mute \(kind.pluralTitle.lowercased())?",
            points: [
                "Issues of this kind will still be listed in the Issues tab.",
                "They will no longer count on the Issues badge.",
                "They will no longer show on the lock screen widget." + (kind == .delay ? " That includes the ? and ! delay marks." : ""),
                "Unmute here or in Settings, under Muted issues.",
            ],
            confirm: "Mute"
        ) { self.setMuted(kind, true) })
    }
}

/// One issue: why you are seeing it, then every update PATH sent about it on a time
/// rail, newest first, then a way to mute its kind.
struct IssueDetailView: View {
    let issue: Issue
    /// Set when it was opened from somewhere that knows why it matters to the user.
    var relevance: IssueRelevance?

    @EnvironmentObject private var model: AppModel
    private var isMuted: Bool { model.mutedKinds.contains(issue.kind) }

    private var lines: [String] {
        (issue.affectedLines.isEmpty ? Array(IssueMatcher.place(of: issue).lines) : issue.affectedLines).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            TagFlow {
                switch relevance {
                case .station: Tag(text: "Your station", color: Theme.Colors.brand, isStrong: true)
                case .line: Tag(text: "Your line", color: Theme.Colors.brand, isStrong: true)
                case nil: EmptyView()
                }
                Tag(text: issue.kind.title, color: issue.kind.color, symbol: issue.kind.symbolName)
                ForEach(lines, id: \.self) { code in
                    Tag(text: code, color: .secondary, dot: PathLines.color(code))
                }
                if let ended = issue.endedAt {
                    Tag(text: "Ended \(PathFormat.dayTime(ended))", color: .secondary)
                } else {
                    Tag(text: "Still open", color: .orange, isStrong: true)
                }
            }
            if issue.detected {
                Text("Noticed by the app from live arrival times, not announced by PATH.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            // Newest first, as PATH's own page lists them.
            let updates = Array(issue.updates.reversed())
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(updates.enumerated()), id: \.element.id) { index, update in
                    // The newest update is the filled dot.
                    RailRow(update: update, isNewest: update.id == issue.updates.last?.id && issue.isActive,
                            isFirst: index == 0, isLast: index == updates.count - 1)
                }
            }
            .accessibilityIdentifier("issueUpdates")
            WideButton(title: isMuted ? "Unmute \(issue.kind.pluralTitle.lowercased())" : "Mute alerts like this",
                       symbol: isMuted ? "bell.fill" : "bell.slash.fill", identifier: "muteRow") {
                model.toggleMute(issue.kind)
            }
            .padding(.top, Theme.Spacing.xs)
        }
    }
}

/// One update on the time rail: when, a dot on the line, and what PATH said.
private struct RailRow: View {
    let update: IssueUpdate
    let isNewest: Bool
    let isFirst: Bool
    let isLast: Bool

    @ScaledMetric(relativeTo: .footnote) private var timeWidth: CGFloat = 66

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(CompactTimes.clockWithPeriod(update.date))
                    .monospacedDigit()
                // The day only when it is not today's.
                if PathTime.ymd(of: update.date) != PathTime.ymd(of: Date()) {
                    Text(PathFormat.relativeDay(update.date, now: Date()))
                        .font(.caption2)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: timeWidth, alignment: .trailing)

            Text(update.body)
                .font(.subheadline)
                .fontWeight(isNewest ? .semibold : .regular)
                // Every word of it: an update is never cut short.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, Theme.Spacing.md + 12)
                .padding(.bottom, isLast ? 0 : Theme.Spacing.lg)
                // The rail: a line the height of this update with its dot at the top.
                .overlay(alignment: .topLeading) {
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(width: 2)
                            .padding(.top, isFirst ? 6 : 0)
                            .opacity(isFirst && isLast ? 0 : 1)
                        Circle()
                            .fill(isNewest ? AnyShapeStyle(Theme.Colors.brand) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                            .overlay { Circle().strokeBorder(isNewest ? AnyShapeStyle(Theme.Colors.brand) : AnyShapeStyle(.secondary), lineWidth: 2) }
                            .frame(width: 12, height: 12)
                            .padding(.top, 3)
                    }
                    .frame(width: 12)
                    .frame(maxHeight: isLast ? 18 : .infinity, alignment: .top)
                }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Open issues first, then ended ones: one section per day, most recent day and end time first.
struct IssuesView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @State private var selected: Issue?

    private var days: [(day: Int, issues: [Issue])] {
        let grouped = Dictionary(grouping: model.issues.archived) { PathTime.ymd(of: $0.endedAt ?? $0.startedAt) }
        return grouped.keys.sorted(by: >).map { day in
            (day, (grouped[day] ?? []).sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) })
        }
    }

    var body: some View {
        ScrollViewReader { reader in
            List {
                Section {
                    if model.issues.active.isEmpty {
                        Label("No issues reported", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.issues.active) { issue in
                        IssueRow(issue: issue, countsOnBadge: !model.mutedKinds.contains(issue.kind),
                                 isMuted: model.mutedKinds.contains(issue.kind)) { selected = $0 }
                    }
                } header: {
                    Text("Current")
                }
                .id("top")
                ForEach(days, id: \.day) { entry in
                    Section {
                        ForEach(entry.issues) { issue in
                            IssueRow(issue: issue, isMuted: model.mutedKinds.contains(issue.kind)) { selected = $0 }
                        }
                    } header: {
                        Text("Archived · " + (PathTime.date(fromYMD: entry.day).map(PathFormat.dayWithYear) ?? ""))
                    }
                }
            }
            .refreshable {
                await model.refreshIssues()
            }
            // The title stays put with nothing behind it; the list fades out underneath.
            .pinnedBarTop { TabTitle(title: "Issues") }
            .onChange(of: model.resetCount[.issues]) {
                selected = nil
                withAnimation { reader.scrollTo("top", anchor: .top) }
            }
        }
        .appSheet(item: $selected, title: { $0.title }) { issue in
            IssueDetailView(issue: issue, relevance: IssueMatcher.relevance(of: issue, station: model.station(nearest: location.station), target: nil))
        }
    }
}
