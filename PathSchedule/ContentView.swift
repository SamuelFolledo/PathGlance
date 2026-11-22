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
            page(.settings) { SettingsView() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar()
        }
    }

    private func page<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        let isShowing = model.tab == tab
        return content()
            .opacity(isShowing ? 1 : 0)
            .allowsHitTesting(isShowing)
            .accessibilityHidden(!isShowing)
    }
}

/// The station button, then the tabs. Tapping the tab already showing resets it.
struct AppTabBar: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService

    private struct Item {
        let tab: AppTab
        let title: String
        let symbol: String
        let id: String
    }

    private let items = [
        Item(tab: .trains, title: "Trains", symbol: "tram.fill", id: "tab-trains"),
        Item(tab: .issues, title: "Issues", symbol: "exclamationmark.triangle.fill", id: "tab-issues"),
        Item(tab: .settings, title: "Settings", symbol: "gearshape.fill", id: "tab-settings"),
    ]

    var body: some View {
        HStack(spacing: 10) {
            StationMenu(onEditFavorites: model.editFavorites) {
                StationBadge(station: model.station(nearest: location.station), size: 44)
                    .padding(6)
                    .background(.regularMaterial, in: .circle)
                    .glassEffect(.regular, in: .circle)
            }
            .accessibilityLabel("From \(model.station(nearest: location.station).name). Change station")
            .accessibilityIdentifier("stationButton")

            HStack(spacing: 0) {
                ForEach(items, id: \.id) { item in
                    button(item)
                }
            }
            .padding(4)
            // A solid enough backing that rows scrolling underneath do not show through the labels.
            .background(.regularMaterial, in: .capsule)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private func button(_ item: Item) -> some View {
        let isSelected = model.tab == item.tab
        let badge = item.tab == .issues ? model.badgeIssues.count : 0
        return Button {
            model.select(item.tab)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: item.symbol)
                    .font(.system(size: 19))
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
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(isSelected ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
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
