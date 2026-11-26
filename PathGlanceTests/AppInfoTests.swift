import Foundation
import Testing
@testable import PathGlance

@Suite struct AppInfoTests {
    @Test func versionTextShowsTheBuildInBrackets() {
        #expect(AppInfo.versionText(version: "1.2", build: "34") == "1.2 (34)")
        #expect(AppInfo.versionText == "\(AppInfo.version) (\(AppInfo.build))")
    }

    @Test func emailGoesToTheDeveloperWithTheVersionAttached() throws {
        let url = try #require(AppInfo.email(subject: "Hello & more", body: "What happened:", details: ["Station: Hoboken"]))
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(parts.scheme == "mailto")
        #expect(parts.path == AppInfo.developerEmail)
        let items = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(items["subject"] == "Hello & more")
        let body = try #require(items["body"])
        #expect(body.hasPrefix("What happened:"))
        #expect(body.contains("Station: Hoboken"))
        #expect(body.contains("App: \(AppInfo.name) \(AppInfo.versionText)"))
        #expect(body.contains("iOS: "))
    }

    @Test func linksPointAtTheSiteAndEveryDonationIsSecure() {
        #expect(AppInfo.privacyPolicy.absoluteString == AppInfo.website.absoluteString + "privacy.html")
        #expect(AppInfo.support.absoluteString == AppInfo.website.absoluteString + "support.html")
        #expect(AppInfo.donations.count == 4)
        #expect(AppInfo.donations.allSatisfy { $0.url.scheme == "https" })
        #expect(Set(AppInfo.donations.map(\.id)).count == AppInfo.donations.count)
    }
}
