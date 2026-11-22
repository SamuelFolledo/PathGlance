import AppIntents
import SwiftUI

/// Lock screen text styles the user can pick in the app. The header is always smaller
/// than the train times.
enum WidgetFontStyle: String, CaseIterable, Identifiable, Sendable {
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
}

/// The train lines of a board, drawn as one block of text so every line shrinks by the
/// same amount when it has to: two lines of different lengths never end up in two sizes.
/// `tapArea` lays a tap target over each line (a `Link` in the widget, a button in the app).
struct BoardLinesView<TapArea: View>: View {
    let board: Board
    let font: Font
    @ViewBuilder var tapArea: (BoardLine) -> TapArea

    var body: some View {
        if board.lines.isEmpty {
            Text("No upcoming trains")
                .font(font)
        } else {
            Text(board.lines.map(\.text).joined(separator: "\n"))
                .font(font)
                .lineLimit(board.lines.count)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.leading)
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
