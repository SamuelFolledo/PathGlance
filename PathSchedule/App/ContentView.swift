import SwiftUI

/// The three tabs under one tab bar of our own. The bar is ours, not the system's, for
/// two things the system's cannot do: a station button beside it, and sheets that run on
/// underneath it while it stays in view.
struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            // All three stay alive so each keeps its place; only the picked one shows.
            page(.trains) { TrainsView() }
            page(.issues) { IssuesView() }
            page(.widget) { WidgetView() }
        }
        // Over whichever tab or sheet asked the question.
        .appSheet(item: $model.guide, style: .popup, title: \.title) { guide in
            GuideView(guide: guide) { model.guide = nil }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar()
        }
        .dynamicTypeSize(model.textSize)
    }

    private func page<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        let isShowing = model.tab == tab
        return content()
            .opacity(isShowing ? 1 : 0)
            .allowsHitTesting(isShowing)
            .accessibilityHidden(!isShowing)
            // The page showing is always on top, so nothing hidden ever lies over it.
            .zIndex(isShowing ? 1 : 0)
    }
}

/// The tabs in a pill centered on the screen, and the station button at its left: the
/// same height, the same look as a tab at rest, and the look of the picked tab while its
/// list is open. Tapping the tab already showing resets it.
struct AppTabBar: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @State private var showsStations = false

    private struct Item {
        let tab: AppTab
        let title: String
        let symbol: String
        let id: String
    }

    private let items = [
        Item(tab: .trains, title: "Trains", symbol: "tram.fill", id: "tab-trains"),
        Item(tab: .issues, title: "Issues", symbol: "exclamationmark.triangle.fill", id: "tab-issues"),
        Item(tab: .widget, title: "Widget", symbol: "rectangle.on.rectangle", id: "tab-widget"),
    ]

    var body: some View {
        // The station button sits right at the pill's left edge, portrait or landscape.
        // An empty space of its size on the other side keeps the pill in the middle;
        // on a screen too narrow for that, the pair is centered instead.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                stationButton
                pill
                Color.clear.frame(width: Theme.Size.tabBar, height: Theme.Size.tabBar)
            }
            HStack(spacing: Theme.Spacing.sm) {
                stationButton
                pill
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private var pill: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.id) { item in
                button(item)
            }
        }
        .padding(Theme.Spacing.xs)
        .frame(width: 250, height: Theme.Size.tabBar)
        // A solid enough backing that rows scrolling underneath do not show through the labels.
        .background(.regularMaterial, in: .capsule)
        .glassEffect(.regular, in: .capsule)
    }

    private var stationButton: some View {
        let station = model.station(nearest: location.station)
        return Button {
            showsStations.toggle()
        } label: {
            Text(station.badge)
                .font(.system(size: station.badge.count > 2 ? 14 : 17, weight: .bold, design: .rounded))
                .foregroundStyle(showsStations ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .frame(width: Theme.Size.tabBar, height: Theme.Size.tabBar)
                .background(showsStations ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear), in: .circle)
                .background(.regularMaterial, in: .circle)
                .glassEffect(.regular, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsStations) {
            StationMenu(isShowing: $showsStations)
        }
        .accessibilityLabel("From \(station.name). Change station")
        .accessibilityAddTraits(showsStations ? .isSelected : [])
        .accessibilityIdentifier("stationButton")
    }

    private func button(_ item: Item) -> some View {
        let isSelected = model.tab == item.tab
        let badge = item.tab == .issues ? model.badgeIssues.count : 0
        return Button {
            model.select(item.tab)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: item.symbol)
                    .font(.system(size: 18))
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Text("\(badge)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.red, in: .capsule)
                                .offset(x: 12, y: -6)
                        }
                    }
                Text(item.title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        // The bar keeps its size whatever the app's text size is set to.
        .dynamicTypeSize(.large)
        .accessibilityLabel(badge > 0 ? "\(item.title), \(badge) open" : item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier(item.id)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
        .environmentObject(LocationService.shared)
}
