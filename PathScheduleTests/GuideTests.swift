import Foundation
import Testing
@testable import PathSchedule

/// Guides keep "don't show again" in the app's defaults, so these put back what they found.
@Suite(.serialized) struct GuideTests {
    private func keepingSilenced(_ body: () -> Void) {
        let saved = UserDefaults.standard.stringArray(forKey: "silencedGuides")
        defer { UserDefaults.standard.set(saved, forKey: "silencedGuides") }
        Guide.showAllAgain()
        body()
    }

    @Test func welcomeShowsAtLaunchUntilSilenced() {
        keepingSilenced {
            #expect(Guide.showsWelcomeAtLaunch(skip: false))
            #expect(!Guide.showsWelcomeAtLaunch(skip: true))
            Guide.silence(Guide.welcomeID)
            #expect(!Guide.showsWelcomeAtLaunch(skip: false))
            Guide.showAllAgain()
            #expect(Guide.showsWelcomeAtLaunch(skip: false))
        }
    }

    @Test func welcomeOnlyInformsAndCanBeSilenced() {
        let guide = Guide.welcome
        #expect(guide.id == Guide.welcomeID)
        #expect(guide.cancel == nil)
        #expect(guide.confirm == "Got it")
        #expect(guide.canBeSilenced)
        #expect(!guide.isDestructive)
        #expect(guide.points.contains { $0.contains("not made, endorsed or supported by PATH") })
        #expect(guide.points.contains { $0.contains("live") })
        #expect(guide.points.contains { $0.contains("timetable") })
    }

    @Test func onlyTheWelcomeNoteIsNumbered() {
        #expect(Guide.welcome.isNumbered)
        #expect(Guide.welcome.points.count == 5)
        #expect(!Guide(id: "x", title: "T", points: ["a"], confirm: "OK", action: {}).isNumbered)
    }

    @Test func otherGuidesKeepTheirCancelButton() {
        let guide = Guide(id: "x", title: "T", points: [], confirm: "OK", action: {})
        #expect(guide.cancel == "Cancel")
    }

    @Test func silencingOneGuideLeavesTheOthers() {
        keepingSilenced {
            Guide.silence("a")
            Guide.silence("a")
            #expect(Guide.isSilenced("a"))
            #expect(!Guide.isSilenced("b"))
            #expect(UserDefaults.standard.stringArray(forKey: "silencedGuides") == ["a"])
        }
    }
}
