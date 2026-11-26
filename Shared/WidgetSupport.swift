import AppIntents
import SwiftUI

/// Lock screen text styles the user can pick in the app. The header is always smaller
/// than the train times.
enum WidgetFontStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case standard, rounded, monospaced, condensed, serif

    var id: String { rawValue }

    var name: String {
        switch self {
        case .standard: return "Standard"
        case .rounded: return "Rounded"
        case .monospaced: return "Monospaced"
        case .condensed: return "Condensed"
        case .serif: return "Serif"
        }
    }

    private func sizes(_ density: WidgetDensity) -> (header: CGFloat, body: CGFloat) {
        let compact: (header: CGFloat, body: CGFloat)
        switch self {
        case .standard, .rounded: compact = (10, 15)
        case .monospaced: compact = (9, 12)
        case .condensed: compact = (10, 16)
        case .serif: compact = (10, 14)
        }
        return density == .compact ? compact : (compact.header + 1, compact.body + 3)
    }

    private var design: Font.Design {
        switch self {
        case .standard, .condensed: return .default
        case .rounded: return .rounded
        case .monospaced: return .monospaced
        case .serif: return .serif
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let font = Font.system(size: size, weight: weight, design: design)
        return self == .condensed ? font.width(.condensed) : font.monospacedDigit()
    }

    /// Always smaller than `bodyFont`.
    func headerFont(_ density: WidgetDensity) -> Font { font(size: sizes(density).header, weight: .medium) }
    func bodyFont(_ density: WidgetDensity) -> Font { font(size: sizes(density).body, weight: .medium) }
    /// Station names, heavier than the times beside them: the header's station and each
    /// line's destination label.
    static let nameWeight = Font.Weight.bold
    func headerNameFont(_ density: WidgetDensity) -> Font { font(size: sizes(density).header, weight: Self.nameWeight) }
    func nameFont(_ density: WidgetDensity) -> Font { font(size: sizes(density).body, weight: Self.nameWeight) }
}

/// The whole lock screen widget: the header row, then the train lines. The widget and the
/// app's preview both draw this, so the preview is the widget.
///
/// The lines are one block of text at a fixed size. It shows as many times per line as
/// fit, trying the most first, so the text is never shrunk and both lines are always the
/// same size. `tapArea` lays a tap target over each line; `decorate` lets the preview color
/// the words an option just changed.
struct BoardWidgetView<Header: View, TapArea: View>: View {
    let board: Board
    let fetchedAt: Date
    let fontStyle: WidgetFontStyle
    let style: WidgetStyle
    var decorate: ((_ line: Int, _ perLine: Int, _ text: String) -> AttributedString)?
    /// Wraps the header row: a refresh button in the widget, nothing in the preview.
    @ViewBuilder var header: (AnyView) -> Header
    @ViewBuilder var tapArea: (BoardLine) -> TapArea

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(AnyView(headerRow))
                .font(fontStyle.headerFont(style.density))
            if board.rows.isEmpty {
                Text("No upcoming trains")
            } else {
                lines
            }
        }
        .font(fontStyle.bodyFont(style.density))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(spacing: 4) {
            Text("From ")
                + Text(board.station.shortName).font(fontStyle.headerNameFont(style.density))
                + Text(": \(CompactTimes.clockWithPeriod(fetchedAt))")
            Image(systemName: "arrow.clockwise")
            if board.hasAlert {
                Image(systemName: "exclamationmark.triangle.fill")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var lines: some View {
        let counts = board.counts(cap: style.maxTimes)
        return ViewThatFits(in: .horizontal) {
            ForEach(counts, id: \.self) { count in
                block(count)
                    .fixedSize(horizontal: true, vertical: false)
            }
            // Even one time does not fit (a long label at the larger size): let it shrink.
            block(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
        .overlay {
            VStack(spacing: 0) {
                ForEach(board.lines, id: \.self) { line in
                    tapArea(line)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel(line.spokenText)
                }
            }
        }
    }

    private func block(_ count: Int) -> some View {
        var text = AttributedString()
        for (index, line) in board.lines(perLine: count).enumerated() {
            if index > 0 { text += AttributedString("\n") }
            var styled = decorate?(index, count, line.text) ?? AttributedString(line.text)
            // The destination is heavier than its times, so the eye finds the line first.
            let name = line.nameLength
            if name > 0, name <= styled.characters.count {
                let end = styled.index(styled.startIndex, offsetByCharacters: name)
                styled[styled.startIndex..<end].font = fontStyle.nameFont(style.density)
            }
            text += styled
        }
        return Text(text)
            .lineLimit(max(board.lines(perLine: count).count, 1))
            .multilineTextAlignment(.leading)
            // Where the view is animated (the app's preview), a change of text fades through.
            .contentTransition(.opacity)
    }
}

extension BoardLine {
    /// For VoiceOver: "To 33rd Street, running late: 7:16 PM, 7:30 PM".
    var spokenText: String {
        let name = target?.name ?? label
        let status = delay == .none ? "" : (delay == .major ? ", long delay" : ", short delay")
        return "To \(name)\(status): " + times.map(CompactTimes.clockWithPeriod).joined(separator: ", ")
    }
}

/// Everything about how the widget looks: what a preset holds, and what "Save" writes.
struct WidgetLook: Hashable, Codable, Sendable {
    var font: WidgetFontStyle = .standard
    var style = WidgetStyle()
}

/// A named look the user can start from.
struct WidgetPreset: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let detail: String
    let look: WidgetLook

    static let builtIn: [WidgetPreset] = [
        WidgetPreset(id: "default", name: "Default", detail: "Full times, compact",
                     look: WidgetLook()),
        WidgetPreset(id: "packed", name: "Packed", detail: "Shortened times, as many trains as fit",
                     look: WidgetLook(font: .condensed, style: WidgetStyle(density: .compact, timeFormat: .short))),
        WidgetPreset(id: "large", name: "Large", detail: "Bigger text, fewer trains",
                     look: WidgetLook(font: .rounded, style: WidgetStyle(density: .regular, timeFormat: .short, maxTimes: 3))),
        WidgetPreset(id: "arrivals", name: "Next train", detail: "The next train and when it arrives",
                     look: WidgetLook(font: .standard, style: WidgetStyle(density: .regular, timeFormat: .full, showArrival: true, maxTimes: 2))),
        WidgetPreset(id: "board", name: "Departure board", detail: "Monospaced, columns line up",
                     look: WidgetLook(font: .monospaced, style: WidgetStyle(density: .compact, timeFormat: .short))),
        WidgetPreset(id: "timetable", name: "Timetable", detail: "Serif, like a printed timetable",
                     look: WidgetLook(font: .serif, style: WidgetStyle(density: .compact, timeFormat: .full))),
        WidgetPreset(id: "soft", name: "Soft", detail: "Rounded text, full times",
                     look: WidgetLook(font: .rounded, style: WidgetStyle(density: .compact, timeFormat: .full))),
        WidgetPreset(id: "commuter", name: "Commuter", detail: "When the next train arrives, then as many as fit",
                     look: WidgetLook(font: .condensed, style: WidgetStyle(density: .compact, timeFormat: .full, showArrival: true))),
        WidgetPreset(id: "nexttwo", name: "Next two", detail: "Big and rounded, only the next two trains",
                     look: WidgetLook(font: .rounded, style: WidgetStyle(density: .regular, timeFormat: .full, maxTimes: 2))),
        WidgetPreset(id: "terminal", name: "Terminal", detail: "Big monospaced text, up to four trains",
                     look: WidgetLook(font: .monospaced, style: WidgetStyle(density: .regular, timeFormat: .short, maxTimes: 4))),
        WidgetPreset(id: "headline", name: "Headline", detail: "Big serif text, up to three trains",
                     look: WidgetLook(font: .serif, style: WidgetStyle(density: .regular, timeFormat: .short, maxTimes: 3))),
    ]

    static func matching(_ look: WidgetLook) -> WidgetPreset? {
        builtIn.first { $0.look == look }
    }
}

/// The refresh button in the widget header. WidgetKit reloads the widget's timeline after
/// any button intent runs, which is all a refresh needs. iOS ignores widget buttons while
/// the phone is locked.
struct RefreshBoardIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh PATH trains"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// Links from the widget into the app.
enum AppLink {
    static let scheme = "pathschedule"

    /// Opens the list of trains from `origin` towards `target`.
    static func line(from origin: Station, to target: Station) -> URL {
        URL(string: "\(scheme)://line?from=\(origin.rawValue)&to=\(target.rawValue)")!
    }

    static func parseLine(_ url: URL) -> (origin: Station, target: Station)? {
        guard url.scheme == scheme, url.host == "line",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let origin = items.first(where: { $0.name == "from" })?.value.flatMap(Station.init(rawValue:)),
              let target = items.first(where: { $0.name == "to" })?.value.flatMap(Station.init(rawValue:)) else { return nil }
        return (origin, target)
    }
}
