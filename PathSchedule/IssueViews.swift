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

    var body: some View {
        NavigationLink {
            IssueDetailView(issue: issue)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: issue.kind.symbolName)
                    .font(.title3)
                    .foregroundStyle(issue.kind.color)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text(PathFormat.span(issue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !issue.latestMessage.isEmpty {
                        Text(issue.latestMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }
}

struct IssueDetailView: View {
    let issue: Issue

    var body: some View {
        List {
            Section {
                Label(issue.kind.title, systemImage: issue.kind.symbolName)
                    .foregroundStyle(issue.kind.color)
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
            }
            Section("Updates") {
                // Newest first.
                ForEach(issue.updates.reversed()) { update in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(PathFormat.dayTime(update.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(update.message.isEmpty ? update.subject : update.message)
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle(issue.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Ended issues, one section per day, most recent day and end time first.
struct ArchivedIssuesView: View {
    @EnvironmentObject private var model: AppModel

    private var days: [(day: Int, issues: [Issue])] {
        let grouped = Dictionary(grouping: model.issues.archived) { PathTime.ymd(of: $0.endedAt ?? $0.startedAt) }
        return grouped.keys.sorted(by: >).map { day in
            (day, (grouped[day] ?? []).sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) })
        }
    }

    var body: some View {
        List {
            if days.isEmpty {
                Text("No past issues yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(days, id: \.day) { entry in
                Section(PathTime.date(fromYMD: entry.day).map(PathFormat.dayWithYear) ?? "") {
                    ForEach(entry.issues) { issue in
                        IssueRow(issue: issue)
                    }
                }
            }
        }
        .navigationTitle("Archived issues")
        .navigationBarTitleDisplayMode(.inline)
    }
}
