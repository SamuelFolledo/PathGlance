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
            HStack(alignment: .top, spacing: 12) {
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
                        .padding(.top, 3)
                        .accessibilityLabel("Muted")
                } else if countsOnBadge {
                    // The same red as the tab's badge: this is one of the issues it counts.
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .padding(.top, 5)
                        .accessibilityLabel("Counted on the Issues badge")
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

    @EnvironmentObject private var model: AppModel

    private var isMuted: Bool { model.mutedKinds.contains(issue.kind) }

    /// Unmuting just happens. Muting is explained first, since it hides things.
    private func toggleMute() {
        let kind = issue.kind
        if isMuted {
            model.setMuted(kind, false)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(issue.kind.title, systemImage: issue.kind.symbolName)
                    .foregroundStyle(issue.kind.color)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: toggleMute) {
                    Label(isMuted ? "Unmute" : "Mute", systemImage: isMuted ? "bell.slash.fill" : "bell.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)
                .accessibilityLabel(isMuted ? "Unmute \(issue.kind.pluralTitle.lowercased())" : "Mute \(issue.kind.pluralTitle.lowercased())")
                .accessibilityIdentifier("muteButton")
                .infoPopover("Mute", "Silences every issue of this kind, not just this one.", "Muted issues stay listed but leave the badge and the lock screen widget.")
            }
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
            Text("Updates")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(issue.updates.reversed()) { update in
                VStack(alignment: .leading, spacing: 4) {
                    Text(PathFormat.dayTime(update.date))
                        .font(.caption)
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
                    Text(model.badgeIssues.isEmpty ? "Current" : "Current · red dot = counted on the badge")
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
        .appSheet(item: $selected, title: { $0.title }) { issue in
            IssueDetailView(issue: issue)
        }
    }
}
