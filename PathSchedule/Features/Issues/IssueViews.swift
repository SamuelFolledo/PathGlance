import SwiftUI

extension IssueKind {
    /// Full color is for the app; the lock screen is monochrome.
    var color: Color {
        switch self {
        case .delay: return .yellow
        case .suspension: return .red
        case .plannedWork: return .orange
        case .elevator: return .blue
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

/// One issue's facts and every update PATH sent about it, newest first.
struct IssueDetailView: View {
    let issue: Issue

    /// Newest update first, or the order they were sent.
    @State private var newestFirst = true
    @State private var showsSort = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(issue.kind.title, systemImage: issue.kind.symbolName)
                .foregroundStyle(issue.kind.color)
                .font(.subheadline.weight(.semibold))
            LabeledContent("Started", value: PathFormat.dayTime(issue.startedAt))
            if let ended = issue.endedAt {
                LabeledContent("Ended", value: PathFormat.dayTime(ended))
            } else {
                LabeledContent("Status", value: "Ongoing")
            }
            if !issue.affectedLines.isEmpty {
                LabeledContent("Lines affected", value: issue.affectedLines.joined(separator: ", "))
            }
            if issue.detected {
                Text("Noticed by the app from live arrival times, not announced by PATH.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Text("Updates")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    showsSort = true
                } label: {
                    Label(newestFirst ? "Newest first" : "Oldest first", systemImage: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("sortUpdates")
                .popover(isPresented: $showsSort) {
                    PopoverMenu {
                        PopoverSectionTitle(title: "Sort updates")
                        PopoverRadioRow(title: "Newest first", isOn: newestFirst) { newestFirst = true; showsSort = false }
                        PopoverRadioRow(title: "Oldest first", isOn: !newestFirst) { newestFirst = false; showsSort = false }
                    }
                }
            }
            ForEach(newestFirst ? issue.updates.reversed() : issue.updates) { update in
                VStack(alignment: .leading, spacing: 4) {
                    Text(PathFormat.dayTime(update.date))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(update.message.isEmpty ? update.subject : update.message)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// The bell beside a sheet's X that silences every issue of one kind. Press and hold for
/// what it does.
struct MuteButton: View {
    let kind: IssueKind

    @EnvironmentObject private var model: AppModel

    private var isMuted: Bool { model.mutedKinds.contains(kind) }

    /// Muting is explained first, since it hides things. Unmuting just happens, except
    /// for elevator notices, which start muted for a reason.
    private func toggle() {
        if isMuted {
            guard kind == .elevator else {
                model.setMuted(kind, false)
                return
            }
            model.ask(Guide(
                id: "unmute-elevator",
                title: "Unmute elevator and escalator notices?",
                points: [
                    "PATH posts these often, and several are usually open at once.",
                    "Each will count on the Issues badge and put the alert mark on the lock screen widget.",
                ],
                confirm: "Unmute"
            ) { model.setMuted(kind, false) })
            return
        }
        model.ask(Guide(
            id: "mute-issues",
            title: "Mute \(kind.pluralTitle.lowercased())?",
            points: [
                "Issues of this kind will still be listed in the Issues tab.",
                "They will no longer count on the Issues badge.",
                "They will no longer show on the lock screen widget." + (kind == .delay ? " That includes the ? and ! delay marks." : ""),
                "Unmute here or in Settings, under Muted issues.",
            ],
            confirm: "Mute"
        ) { model.setMuted(kind, true) })
    }

    var body: some View {
        RoundButton(symbol: isMuted ? "bell.slash.fill" : "bell.fill",
                    label: isMuted ? "Unmute \(kind.pluralTitle.lowercased())" : "Mute \(kind.pluralTitle.lowercased())",
                    isOn: isMuted, identifier: "muteButton", action: toggle)
            .infoPopover(isMuted ? "Muted" : "Mute",
                         "Silences every issue of this kind (\(kind.pluralTitle.lowercased())), not just this one.",
                         "Muted issues stay listed here but leave the Issues badge and the lock screen widget.",
                         "Tap again to unmute.")
    }
}

/// Open issues first, then ended ones: one section per day, most recent day and end time first.
struct IssuesView: View {
    @EnvironmentObject private var model: AppModel
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
                Text("Issues")
                    .font(.largeTitle.weight(.bold))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
                    .accessibilityAddTraits(.isHeader)
                    .id("top")
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
            .onChange(of: model.resetCount[.issues]) {
                selected = nil
                withAnimation { reader.scrollTo("top", anchor: .top) }
            }
        }
        .appSheet(item: $selected, title: { $0.title },
                  subtitle: { _ in "Every update PATH sent about this." },
                  accessory: { AnyView(MuteButton(kind: $0.kind)) }) { issue in
            IssueDetailView(issue: issue)
        }
    }
}
