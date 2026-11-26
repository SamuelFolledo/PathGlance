import SwiftUI

/// A short explanation shown before an action that matters: what it will do, one point
/// per line, with Cancel and a confirming button. Most can be ticked "Don't show this
/// again"; a destructive one always asks. One with no `cancel` only informs, and has
/// the single confirming button.
struct Guide: Identifiable {
    /// Also the key the "don't show again" choice is kept under.
    let id: String
    let title: String
    let points: [String]
    let confirm: String
    /// The title of the button that backs out. `nil` leaves only the confirming button.
    var cancel: String? = "Cancel"
    var isDestructive = false
    var canBeSilenced = true
    /// Shows the points as a numbered list (1., 2., ...) instead of plain paragraphs.
    var isNumbered = false
    let action: () -> Void

    private static let key = "silencedGuides"

    static func isSilenced(_ id: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: key) ?? []).contains(id)
    }

    static func silence(_ id: String) {
        var all = UserDefaults.standard.stringArray(forKey: key) ?? []
        if !all.contains(id) { all.append(id) }
        UserDefaults.standard.set(all, forKey: key)
    }

    static func showAllAgain() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

extension Guide {
    static let welcomeID = "welcome"

    /// What a new user should know before trusting a time: shown when the app opens,
    /// every time, until "Don't show this again" is ticked. Also under Settings, About.
    static var welcome: Guide {
        Guide(
            id: welcomeID,
            title: "Welcome to \(AppInfo.name)",
            points: [
                "This is an independent app. It is not made, endorsed or supported by PATH or the Port Authority (yet).",
                "The next train or two on each line are live from PATH's own feed. They have a green dot, or a yellow one when running late.",
                "Every other time is PATH's published timetable. PATH can change it, and trains can run early or late.",
                "Your location is only used to pick the nearest station, and it stays on your phone.",
                "Add the lock screen widget from the Widget tab, and press and hold almost anything for more.",
            ],
            confirm: "Got it",
            cancel: nil,
            isNumbered: true,
            action: {}
        )
    }

    /// Whether the welcome note opens with the app. `skip` is the "-skipWelcome YES"
    /// launch argument, for UI tests and screenshots.
    static func showsWelcomeAtLaunch(skip: Bool = UserDefaults.standard.bool(forKey: "skipWelcome")) -> Bool {
        !skip && !isSilenced(welcomeID)
    }
}

/// A button as wide as the space it is given, for the bottom of a popup: one spans the
/// popup, two side by side in an `HStack` split it evenly.
struct WideButton: View {
    let title: String
    var symbol: String?
    var role: ButtonRole?
    var isProminent = false
    var identifier = ""
    let action: () -> Void

    var body: some View {
        if isProminent {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.glass)
        }
    }

    private var button: some View {
        Button(role: role, action: action) {
            Group {
                if let symbol { Label(title, systemImage: symbol) } else { Text(title) }
            }
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 30)
        }
        .accessibilityIdentifier(identifier)
    }
}

/// The body of the popup a `Guide` is shown in.
struct GuideView: View {
    let guide: Guide
    let close: () -> Void

    @State private var dontShowAgain = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(guide.points.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if guide.isNumbered {
                        Text("\(index + 1).")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    Text(point)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.callout)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(guide.isNumbered ? "\(index + 1). \(point)" : point)
            }
            if guide.canBeSilenced {
                CheckRow(isOn: dontShowAgain, shape: .square) {
                    dontShowAgain.toggle()
                } label: {
                    Text("Don't show this again")
                }
                .accessibilityIdentifier("guideDontShowAgain")
            }
            HStack(spacing: 12) {
                if let cancel = guide.cancel {
                    WideButton(title: cancel, identifier: "guideCancel", action: close)
                }
                WideButton(title: guide.confirm, role: guide.isDestructive ? .destructive : nil, isProminent: true, identifier: "guideConfirm") {
                    if dontShowAgain { Guide.silence(guide.id) }
                    close()
                    guide.action()
                }
            }
            .padding(.top, 4)
        }
    }
}
