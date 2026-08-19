import SwiftUI

@main
struct PandaBeFreeWatchApp: App {
    @State private var model = WatchAppModel()

    var body: some Scene {
        WindowGroup {
            WatchDashboardView(model: model)
        }
    }
}
