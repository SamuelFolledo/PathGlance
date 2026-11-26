import SwiftUI

@main struct MyApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Created here so region events are handled when iOS relaunches the app in the background.
        LocationService.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environmentObject(LocationService.shared)
                .tint(Theme.Colors.brand)
                .onOpenURL { url in
                    // A tap on a widget line.
                    if let line = AppLink.parseLine(url) {
                        model.open(origin: line.origin, target: line.target)
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.becameActive()
            }
        }
        .backgroundTask(.appRefresh(AppModel.refreshTaskID)) {
            await AppModel.backgroundRefresh()
        }
    }
}
