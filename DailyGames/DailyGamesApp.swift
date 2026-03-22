import SwiftUI
import SwiftData

@main
struct DailyGamesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([GameDay.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject private var prefetchManager: GamePrefetchManager

    init() {
        let container = sharedModelContainer
        _prefetchManager = StateObject(wrappedValue: GamePrefetchManager(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(prefetchManager)
                .modelContainer(sharedModelContainer)
        }
    }
}
