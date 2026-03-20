import SwiftUI

@main
struct DailyGamesApp: App {
    @StateObject private var prefetchManager = GamePrefetchManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(prefetchManager)
        }
    }
}
