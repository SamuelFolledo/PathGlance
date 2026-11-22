import SwiftUI
import UIKit

/// The facts about the app that are not settings: its version, where its website is,
/// who to write to. One place, so a new name or address is changed once.
enum AppInfo {
    static let developer = "Samuel Folledo"
    static let developerEmail = "samuelfolledo@gmail.com"

    /// The landing site. `scripts/build_release.sh` uploads `landing/` here.
    static let website = URL(string: "https://samuelfolledo.com/apps/path-schedule/")!
    static let privacyPolicy = website.appending(path: "privacy.html")
    static let support = website.appending(path: "support.html")

    static let disclaimer = "An independent app. Not affiliated with, endorsed by, or sponsored by the Port Authority of New York and New Jersey or PATH."

    static var name: String {
        info("CFBundleDisplayName") ?? info("CFBundleName") ?? "PathSchedule"
    }

    /// "1.0", as on the App Store.
    static var version: String { info("CFBundleShortVersionString") ?? "?" }

    /// The build number, which rises with every upload.
    static var build: String { info("CFBundleVersion") ?? "?" }

    /// "1.0 (3)".
    static var versionText: String { versionText(version: version, build: build) }

    static func versionText(version: String, build: String) -> String {
        "\(version) (\(build))"
    }

    struct Donation: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let color: Color
        let url: URL
    }

    static let donations = [
        Donation(id: "coffee", title: "Buy Me a Coffee", symbol: "cup.and.saucer.fill", color: .yellow, url: URL(string: "https://buymeacoffee.com/samuelfolledo")!),
        Donation(id: "paypal", title: "PayPal", symbol: "p.circle.fill", color: .blue, url: URL(string: "https://paypal.me/samuelfolledo")!),
        Donation(id: "venmo", title: "Venmo", symbol: "v.circle.fill", color: .indigo, url: URL(string: "https://venmo.com/u/samuelfolledo")!),
        Donation(id: "cashapp", title: "Cash App", symbol: "dollarsign.circle.fill", color: .green, url: URL(string: "https://cash.app/$SamuelFolledo")!),
    ]

    /// An email to the developer. Every message ends with the app version, the iOS
    /// version and anything in `details`, so a report can be acted on without a reply
    /// asking which build it was.
    static func email(subject: String, body: String = "", details: [String] = []) -> URL? {
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = developerEmail
        let footer = (details + ["App: \(name) \(versionText)", "iOS: \(UIDevice.current.systemVersion)"])
            .joined(separator: "\n")
        parts.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: "\(body)\n\n\n\(footer)"),
        ]
        return parts.url
    }

    private static func info(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
