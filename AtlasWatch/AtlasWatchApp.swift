import SwiftUI

@main
struct AtlasWatchApp: App {
    @State private var client = WatchConnectivityClient()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(client)
                .task { client.activate() }
        }
    }
}
