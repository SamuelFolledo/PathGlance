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
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.becameActive()
            }
        }
    }
}
