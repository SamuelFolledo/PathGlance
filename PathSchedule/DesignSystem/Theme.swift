import SwiftUI

/// The app's one set of measurements. Screens use these names, never their own numbers,
/// so padding, spacing and corners match everywhere.
enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        /// From the screen's edge to content, and from a card's edge to what is in it.
        static let contentSide: CGFloat = 16
        /// Above and below a row's content.
        static let row: CGFloat = 11
    }

    enum Radius {
        static let card: CGFloat = 22
        static let sheet: CGFloat = 28
    }

    enum Size {
        /// The tab bar and the station button beside it.
        static let tabBar: CGFloat = 54
        static let roundButton: CGFloat = 32
        static let dot: CGFloat = 8
    }

    enum Motion {
        static let sheet: Animation = .snappy(duration: 0.3)
        static let content: Animation = .smooth(duration: 0.35)
    }
}

extension View {
    /// A grouped card: the surface rows and sections sit on, with the standard corners.
    func card() -> some View {
        background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.Radius.card))
    }
}
