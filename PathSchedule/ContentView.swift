import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    /// Issues worth a badge: everything open except elevator notices.
    private var badge: Int {
        model.issues.active.filter { $0.kind != .elevator }.count
    }

    var body: some View {
        TabView(selection: $model.tab) {
            Tab("Trains", systemImage: "tram.fill", value: AppTab.trains) {
                TrainsView()
            }
            Tab("Issues", systemImage: "exclamationmark.triangle", value: AppTab.issues) {
                IssuesView()
            }
            .badge(badge)
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
        .environmentObject(LocationService.shared)
}
