import SwiftUI

/// The Issues tab: a tab per line, and under it the line drawn as its stops, each open
/// issue written out at the stop it names. Issues that name the line but no stop sit
/// above the stops; issues that name nothing sit under every tab; ended ones are one
/// row at the bottom.
struct IssuesView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService

    /// The tab that is underlined, and the page showing. They part only mid-swipe.
    @State private var chosen: IssueTab?
    @State private var page: IssueTab?
    @State private var sheet: Sheet?

    private enum Sheet: Identifiable {
        case issue(Issue)
        case archive

        var id: String {
            switch self {
            case .issue(let issue): return "issue-\(issue.id)"
            case .archive: return "archive"
            }
        }
    }

    private var tabs: [IssueTab] { IssueBoard.tabs(order: model.lineOrder) }
    private var current: IssueTab { chosen ?? tabs.first ?? .journalSquare33 }
    private var station: Station { model.station(nearest: location.station) }

    private func tab(_ tab: IssueTab, issues: [Issue]) -> UnderlineTab<IssueTab> {
        let count = IssueBoard.count(tab, issues: issues, muted: model.mutedKinds)
        return UnderlineTab(id: tab, title: tab.title,
                            detail: count == 0 ? "Good" : "\(count) issue\(count == 1 ? "" : "s")",
                            detailColor: count == 0 ? .green : .orange,
                            spokenTitle: tab.spokenTitle)
    }

    var body: some View {
        let issues = model.boardIssues
        VStack(spacing: 0) {
            TabTitle(title: "Issues")
            UnderlineTabs(tabs: tabs.map { tab($0, issues: issues) }, selection: current) { picked in
                chosen = picked
                withAnimation(.snappy) { page = picked }
            }
            .padding(.horizontal, Theme.Spacing.contentSide)
            .padding(.top, Theme.Spacing.sm)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("issueTabs")

            // The lines page sideways like the lines on the Trains tab.
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        IssueLinePage(tab: tab, issues: issues, station: station, muted: model.mutedKinds,
                                      archivedCount: model.issues.archived.count, resets: model.resetCount[.issues] ?? 0,
                                      open: { sheet = .issue($0) }, openArchive: { sheet = .archive },
                                      refresh: { await model.refreshIssues() })
                            .containerRelativeFrame(.horizontal)
                            .id(tab)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                if phase == .idle, let page, page != current { chosen = page }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: model.resetCount[.issues]) { sheet = nil }
        .appSheet(item: $sheet, title: { sheet in
            switch sheet {
            case .issue(let issue): return issue.title
            case .archive: return "Archived"
            }
        }) { sheet in
            switch sheet {
            case .issue(let issue):
                IssueDetailView(issue: issue, relevance: IssueMatcher.relevance(of: issue, station: station, target: nil))
            case .archive:
                IssueArchiveList(issues: model.issues.archived, muted: model.mutedKinds) { self.sheet = .issue($0) }
            }
        }
    }
}

/// One tab's page: its line or lines, then what fits no line, then the archive.
private struct IssueLinePage: View {
    let tab: IssueTab
    let issues: [Issue]
    let station: Station
    let muted: Set<IssueKind>
    let archivedCount: Int
    let resets: Int
    let open: (Issue) -> Void
    let openArchive: () -> Void
    let refresh: () async -> Void

    var body: some View {
        let other = IssueBoard.other(issues)
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Color.clear
                        .frame(height: 0)
                        .id("top")
                    ForEach(tab.lines, id: \.self) { code in
                        let strip = IssueBoard.strip(code, issues: issues)
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            // One line needs no name: the tab says it.
                            if tab.lines.count > 1 {
                                HStack(spacing: 6) {
                                    Circle().fill(PathLines.color(code)).frame(width: Theme.Size.dot, height: Theme.Size.dot)
                                    Text(IssueBoard.name(of: code))
                                }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, Theme.Spacing.xs)
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isHeader)
                            }
                            IssueStripCard(strip: strip, station: station, muted: muted, open: open)
                        }
                    }
                    if !other.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Other")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, Theme.Spacing.xs)
                                .accessibilityAddTraits(.isHeader)
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                ForEach(other) { issue in
                                    IssueEntry(issue: issue, isMuted: muted.contains(issue.kind), name: "otherIssue", open: open)
                                }
                            }
                            .padding(Theme.Spacing.contentSide)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                        }
                        .infoPopover("Other", "PATH's wording for these names no line and no station, so they are listed under every line.")
                    }
                    OpenRow(title: "Archived", value: archivedCount == 0 ? "None" : "\(archivedCount)", action: openArchive)
                        .padding(.horizontal, Theme.Spacing.contentSide)
                        .padding(.vertical, Theme.Spacing.row)
                        .card()
                        .accessibilityIdentifier("archivedRow")
                }
                .padding(.horizontal, Theme.Spacing.contentSide)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .refreshable { await refresh() }
            .onChange(of: resets) {
                withAnimation { reader.scrollTo("top", anchor: .top) }
            }
        }
    }
}

/// A line as a card: how it is doing, anything about the whole line, then its stops on a rail.
private struct IssueStripCard: View {
    let strip: IssueStrip
    let station: Station
    let muted: Set<IssueKind>
    let open: (Issue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if strip.issues.isEmpty {
                Label("Good service", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("goodService-\(strip.code)")
            }
            if !strip.wholeLine.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Whole line")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(strip.wholeLine) { issue in
                        IssueEntry(issue: issue, isMuted: muted.contains(issue.kind), name: "lineIssue", open: open)
                    }
                }
                Divider()
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(strip.stops.enumerated()), id: \.element.id) { index, stop in
                    IssueStopRow(stop: stop, lineColor: PathLines.color(strip.code), isYou: stop.station == station, muted: muted,
                                 isFirst: index == 0, isLast: index == strip.stops.count - 1, open: open)
                }
            }
        }
        .padding(Theme.Spacing.contentSide)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// One stop on the rail: a quiet name, or the name and every issue there.
private struct IssueStopRow: View {
    let stop: IssueStop
    let lineColor: Color
    let isYou: Bool
    let muted: Set<IssueKind>
    let isFirst: Bool
    let isLast: Bool
    let open: (Issue) -> Void

    /// The marker takes the colour of the first issue that is not muted.
    private var markerColor: Color? {
        (stop.issues.first { !muted.contains($0.kind) } ?? stop.issues.first)?.kind.color
    }

    var body: some View {
        let hasIssues = !stop.issues.isEmpty
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(stop.station.name)
                    .font(.subheadline)
                    .fontWeight(hasIssues || isYou ? .semibold : .regular)
                    .foregroundStyle(hasIssues || isYou ? .primary : .secondary)
                if isYou {
                    Tag(text: "You", color: Theme.Colors.brand, isStrong: true)
                        .accessibilityLabel("Your station")
                }
            }
            .accessibilityElement(children: .combine)
            ForEach(stop.issues) { issue in
                IssueEntry(issue: issue, isMuted: muted.contains(issue.kind), name: "stopIssue", open: open)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 28)
        .padding(.bottom, isLast ? 0 : (hasIssues ? Theme.Spacing.lg : Theme.Spacing.md))
        // The rail: the line in its map colour for the height of this stop, its dot at the top.
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(lineColor.opacity(0.45))
                    .frame(width: 3)
                    .padding(.top, isFirst ? 8 : 0)
                    .opacity(isFirst && isLast ? 0 : 1)
                Circle()
                    .fill(markerColor.map(AnyShapeStyle.init) ?? AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                    .overlay { Circle().strokeBorder(markerColor ?? lineColor, lineWidth: 2.5) }
                    .frame(width: 14, height: 14)
                    .padding(.top, 3)
            }
            .frame(width: 14)
            .frame(maxHeight: isLast ? 17 : .infinity, alignment: .top)
            .accessibilityHidden(true)
        }
    }
}

/// An issue written out where it applies: what it is, then every update PATH sent,
/// newest first. Tapping it opens the issue's sheet.
private struct IssueEntry: View {
    let issue: Issue
    let isMuted: Bool
    /// The start of its accessibility identifier: where on the page it sits.
    let name: String
    let open: (Issue) -> Void

    @ScaledMetric(relativeTo: .footnote) private var timeWidth: CGFloat = 62
    @Environment(\.dynamicTypeSize) private var textSize

    private func time(_ date: Date) -> String {
        PathTime.ymd(of: date) == PathTime.ymd(of: Date()) ? CompactTimes.clockWithPeriod(date) : PathFormat.dayTime(date)
    }

    var body: some View {
        Button {
            open(issue)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: issue.kind.symbolName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(issue.kind.color)
                        .accessibilityLabel(issue.kind.title)
                    Text(issue.title)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)
                    if isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Muted")
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                // Newest first, as PATH's own page lists them.
                ForEach(issue.updates.reversed()) { update in
                    Group {
                        if textSize.isAccessibilitySize {
                            // Large text: the time goes above what PATH said.
                            VStack(alignment: .leading, spacing: 0) {
                                Text(time(update.date))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Text(update.body)
                            }
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                                Text(time(update.date))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: timeWidth, alignment: .leading)
                                    .fixedSize()
                                Text(update.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the issue")
        .accessibilityIdentifier("\(name)-\(issue.id)")
    }
}

/// Ended issues: one group per day, most recent day and end time first.
private struct IssueArchiveList: View {
    let issues: [Issue]
    let muted: Set<IssueKind>
    let open: (Issue) -> Void

    private var days: [(day: Int, issues: [Issue])] {
        let grouped = Dictionary(grouping: issues) { PathTime.ymd(of: $0.endedAt ?? $0.startedAt) }
        return grouped.keys.sorted(by: >).map { day in
            (day, (grouped[day] ?? []).sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) })
        }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            if issues.isEmpty {
                Label("Nothing archived yet", systemImage: "archivebox")
                    .foregroundStyle(.secondary)
            }
            ForEach(days, id: \.day) { entry in
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(PathTime.date(fromYMD: entry.day).map(PathFormat.dayWithYear) ?? "")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        ForEach(entry.issues) { issue in
                            IssueRow(issue: issue, isMuted: muted.contains(issue.kind), open: open)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("archiveList")
    }
}
