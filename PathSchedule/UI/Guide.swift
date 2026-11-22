import SwiftUI

/// A short explanation shown before an action that matters: what it will do, one point
/// per line, with Cancel and a confirming button. Most can be ticked "Don't show this
/// again"; a destructive one always asks.
struct Guide: Identifiable {
    /// Also the key the "don't show again" choice is kept under.
    let id: String
    let title: String
    let points: [String]
    let confirm: String
    var isDestructive = false
    var canBeSilenced = true
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

/// The body of the popup a `Guide` is shown in.
struct GuideView: View {
    let guide: Guide
    let close: () -> Void

    @State private var dontShowAgain = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(guide.points, id: \.self) { point in
                Text(point)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if guide.canBeSilenced {
                CheckRow(isOn: dontShowAgain) {
                    dontShowAgain.toggle()
                } label: {
                    Text("Don't show this again")
                }
                .accessibilityIdentifier("guideDontShowAgain")
            }
            HStack(spacing: 12) {
                Button("Cancel", action: close)
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("guideCancel")
                Button(guide.confirm, role: guide.isDestructive ? .destructive : nil) {
                    if dontShowAgain { Guide.silence(guide.id) }
                    close()
                    guide.action()
                }
                .buttonStyle(.glassProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("guideConfirm")
            }
            .padding(.top, 4)
        }
    }
}
