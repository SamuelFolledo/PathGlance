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

    private var sizes: (header: CGFloat, body: CGFloat) {
        switch self {
        case .standard, .rounded: return (10, 15)
        case .monospaced: return (9, 12)
        case .condensed: return (10, 16)
        case .serif: return (10, 14)
        }
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

    var headerFont: Font { font(size: sizes.header, weight: .medium) }
    var bodyFont: Font { font(size: sizes.body, weight: .medium) }
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
