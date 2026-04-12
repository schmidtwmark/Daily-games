import SwiftUI
import SwiftData
import WebKit

enum PrefetchState: Equatable {
    case idle
    case fetching
    case waitingForJS
    case checkingCompletion
    case ready
    case failed

    var isLoading: Bool {
        switch self {
        case .fetching, .waitingForJS, .checkingCompletion:
            return true
        default:
            return false
        }
    }

    var statusText: String {
        switch self {
        case .idle: return "Waiting..."
        case .fetching: return "Fetching..."
        case .waitingForJS: return "Rendering..."
        case .checkingCompletion: return "Checking..."
        case .ready: return "Ready"
        case .failed: return "Failed"
        }
    }
}

/// Extended game result data
struct GameResultData: Equatable {
    let won: Bool
    // Wordle-specific
    let guesses: Int?
    // Connections-specific
    let mistakes: Int?
    // Puzzmo-specific
    let streak: Int?
    let maxStreak: Int?
    let totalPlayed: Int?
    // Bracket City-specific
    let errors: Int?
    let rating: String?
    // Raddle-specific
    let hintFreePercent: Int?

    init(won: Bool, guesses: Int? = nil, mistakes: Int? = nil, streak: Int? = nil, maxStreak: Int? = nil, totalPlayed: Int? = nil, errors: Int? = nil, rating: String? = nil, hintFreePercent: Int? = nil) {
        self.won = won
        self.guesses = guesses
        self.mistakes = mistakes
        self.streak = streak
        self.maxStreak = maxStreak
        self.totalPlayed = totalPlayed
        self.errors = errors
        self.rating = rating
        self.hintFreePercent = hintFreePercent
    }

    init?(json: [String: Any]) {
        guard let completed = json["completed"] as? Bool, completed else { return nil }
        self.won = json["won"] as? Bool ?? false
        self.guesses = json["guesses"] as? Int
        self.mistakes = json["mistakes"] as? Int
        self.streak = json["streak"] as? Int
        self.maxStreak = json["maxStreak"] as? Int
        self.totalPlayed = json["totalPlayed"] as? Int
        self.errors = json["errors"] as? Int
        self.rating = json["rating"] as? String
        self.hintFreePercent = json["hintFreePercent"] as? Int
    }

    /// Convert to GameData for persistence
    func toGameData(gameId: String, isAvailable: Bool = true) -> GameData {
        GameData(
            gameId: gameId,
            isAvailable: isAvailable,
            isCompleted: true,
            isWon: won,
            guesses: guesses,
            mistakes: mistakes,
            streak: streak,
            maxStreak: maxStreak,
            totalPlayed: totalPlayed,
            errors: errors,
            rating: rating,
            hintFreePercent: hintFreePercent,
            lastChecked: Date()
        )
    }
}

enum CompletionStatus: Equatable {
    case unknown
    case incomplete
    case completed(GameResultData)

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    var won: Bool {
        if case .completed(let data) = self { return data.won }
        return false
    }

    var resultData: GameResultData? {
        if case .completed(let data) = self { return data }
        return nil
    }
}

/// Display status for games in the list view
enum GameDisplayStatus: Equatable {
    case loading
    case unavailable       // Game doesn't exist for this date (grayed out)
    case incomplete
    case completed(GameResultData)
    case unknown
}

@MainActor
class GamePrefetchManager: ObservableObject {
    @Published var displayStatus: [String: GameDisplayStatus] = [:]
    @Published var prefetchState: [String: PrefetchState] = [:]
    let debugLogger = DebugLogger()

    private var webViews: [String: WKWebView] = [:]
    private var coordinators: [String: PrefetchCoordinator] = [:]
    private var currentDates: [String: Date] = [:]
    /// Tracks when each game was last fetched (date component only, not time)
    private var lastFetchDates: [String: Date] = [:]
    /// Tracks the date when we last loaded/refreshed
    private var lastLoadDate: Date?

    private let modelContainer: ModelContainer
    private let debugDirectory: URL
    private let calendar = Calendar.current

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        debugDirectory = docs.appendingPathComponent("Daily Games")

        print("📁 Debug directory: \(debugDirectory.path)")

        for game in Game.allCases {
            displayStatus[game.id] = .unknown
            prefetchState[game.id] = .idle
        }

        // Clean and recreate debug directory
        do {
            if FileManager.default.fileExists(atPath: debugDirectory.path) {
                try FileManager.default.removeItem(at: debugDirectory)
                print("📁 Removed existing debug directory")
            }
            try FileManager.default.createDirectory(at: debugDirectory, withIntermediateDirectories: true)
            print("📁 Created debug directory successfully")
        } catch {
            print("📁 Error creating debug directory: \(error)")
        }
    }

    // MARK: - Database Operations

    @MainActor
    private func fetchOrCreateDay(for date: Date) -> GameDay {
        let context = modelContainer.mainContext
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        let predicate = #Predicate<GameDay> { $0.dateString == dateString }
        let descriptor = FetchDescriptor(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let newDay = GameDay(date: date)
        context.insert(newDay)
        try? context.save()
        return newDay
    }

    @MainActor
    private func updateGameData(game: Game, date: Date, data: GameData) {
        let context = modelContainer.mainContext
        let day = fetchOrCreateDay(for: date)
        day.updateGame(game, with: data)
        try? context.save()
    }

    // MARK: - Load and Refresh

    /// Check if it's a new day since last load and refresh if so
    func checkForNewDay() {
        let today = calendar.startOfDay(for: Date())

        // If we've never loaded, or if the day has changed, do a full refresh
        if lastLoadDate == nil || !calendar.isDate(lastLoadDate!, inSameDayAs: today) {
            print("📅 New day detected, refreshing all games")
            // Clear the in-memory fetch dates so everything gets refreshed
            lastFetchDates.removeAll()
            // Reset display status to unknown
            for game in Game.allCases {
                displayStatus[game.id] = .unknown
                prefetchState[game.id] = .idle
            }
            loadAndRefreshAll()
        }
    }

    /// Load cached records from SwiftData, update UI immediately, then prefetch all games
    func loadAndRefreshAll() {
        let today = calendar.startOfDay(for: Date())
        lastLoadDate = today

        // Step 1: Load cached data from database and update UI immediately
        let day = fetchOrCreateDay(for: today)
        for game in Game.allCases {
            if let gameData = day.gameData(for: game) {
                if !gameData.isAvailable {
                    displayStatus[game.id] = .unavailable
                } else if gameData.isCompleted {
                    let resultData = GameResultData(
                        won: gameData.isWon,
                        guesses: gameData.guesses,
                        mistakes: gameData.mistakes,
                        streak: gameData.streak,
                        maxStreak: gameData.maxStreak,
                        totalPlayed: gameData.totalPlayed,
                        errors: gameData.errors,
                        rating: gameData.rating,
                        hintFreePercent: gameData.hintFreePercent
                    )
                    displayStatus[game.id] = .completed(resultData)
                } else if gameData.lastChecked != nil {
                    displayStatus[game.id] = .incomplete
                }
            }
        }

        // Step 2: Prefetch all games that haven't been fetched today
        for game in Game.allCases {
            // Skip if already fetched today
            if let lastFetch = lastFetchDates[game.id],
               calendar.isDate(lastFetch, inSameDayAs: today) {
                print("📦 [\(game.name)] Already fetched today")
                continue
            }
            prefetch(game: game, for: today, reason: "Refreshed on opening")
        }
    }

    /// Prefetch all games that haven't been fetched today
    func prefetchAll() {
        loadAndRefreshAll()
    }

    func prefetch(game: Game, for date: Date, reason: String = "Prefetch") {
        prefetchState[game.id] = .fetching
        currentDates[game.id] = date
        lastFetchDates[game.id] = calendar.startOfDay(for: date)

        let webView = getOrCreateWebView(for: game)
        let url = game.url(for: date)
        print("🌐 [\(game.name)] Starting prefetch: \(url.absoluteString)")

        debugLogger.log(game: game, entry: DebugLogEntry(
            type: .request,
            reason: reason,
            summary: "Loading \(url.absoluteString)",
            details: ["URL": url.absoluteString, "Date": "\(date)"]
        ))

        let startTime = Date()
        webView.load(URLRequest(url: url))

        // Timeout detection - warn if load takes too long
        Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            await MainActor.run {
                if self.prefetchState[game.id]?.isLoading == true {
                    let elapsed = Date().timeIntervalSince(startTime)
                    print("⚠️ [\(game.name)] Still loading after \(String(format: "%.1f", elapsed))s - may be stuck")
                    print("⚠️ [\(game.name)] WebView isLoading: \(webView.isLoading), URL: \(webView.url?.absoluteString ?? "nil")")
                    print("⚠️ [\(game.name)] State: \(self.prefetchState[game.id]?.statusText ?? "unknown")")
                }
            }
        }
    }

    func webView(for game: Game) -> WKWebView {
        return getOrCreateWebView(for: game)
    }

    func currentDate(for game: Game) -> Date {
        return currentDates[game.id] ?? Date()
    }

    /// Check if a game needs to be fetched (no cached result for today)
    func needsFetch(for game: Game) -> Bool {
        let today = calendar.startOfDay(for: Date())
        guard let lastFetch = lastFetchDates[game.id] else { return true }
        return !calendar.isDate(lastFetch, inSameDayAs: today)
    }

    /// Force refresh all games (ignores cache)
    func refreshAll() {
        for game in Game.allCases {
            let date = currentDates[game.id] ?? Date()
            prefetch(game: game, for: date, reason: "Refresh button")
        }
    }

    private func getOrCreateWebView(for game: Game) -> WKWebView {
        if let existing = webViews[game.id] {
            return existing
        }

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true

        let coordinator = PrefetchCoordinator(manager: self, game: game)
        webView.navigationDelegate = coordinator

        webViews[game.id] = webView
        coordinators[game.id] = coordinator

        return webView
    }

    // MARK: - Completion Checking

    /// Evaluate the completion script and return parsed JSON (or nil)
    private func evaluateCompletionScript(for game: Game) async -> [String: Any]? {
        guard let webView = webViews[game.id] else { return nil }
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(game.completionScript) { result, _ in
                if let jsonString = result as? String,
                   let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    continuation.resume(returning: json)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Get page content hash for change detection
    private func getPageContentHash(for game: Game) async -> Int? {
        guard let webView = webViews[game.id] else { return nil }
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("document.body.innerText") { result, _ in
                if let text = result as? String {
                    continuation.resume(returning: text.hashValue)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Process a completion check result, update state + database, return whether completed
    @discardableResult
    private func processCompletionResult(game: Game, json: [String: Any]?, reason: String) -> Bool {
        let date = currentDates[game.id] ?? Date()

        guard let json = json else {
            debugLogger.log(game: game, entry: DebugLogEntry(
                type: .completionCheck,
                reason: reason,
                summary: "Script returned nil",
                details: ["Result": "nil"]
            ))
            displayStatus[game.id] = .unknown
            return false
        }

        let completed = json["completed"] as? Bool ?? false
        let available = json["available"] as? Bool ?? true

        debugLogger.log(game: game, entry: DebugLogEntry(
            type: .completionCheck,
            reason: reason,
            summary: completed ? "Completed" : (available ? "Incomplete" : "Unavailable"),
            details: json.mapValues { "\($0)" }
        ))

        if !available {
            displayStatus[game.id] = .unavailable
            let gameData = GameData(
                gameId: game.id,
                isAvailable: false,
                isCompleted: false,
                isWon: false,
                lastChecked: Date()
            )
            updateGameData(game: game, date: date, data: gameData)
            return false
        }

        if completed, let resultData = GameResultData(json: json) {
            displayStatus[game.id] = .completed(resultData)
            updateGameData(game: game, date: date, data: resultData.toGameData(gameId: game.id))
            return true
        } else if completed {
            let won = json["won"] as? Bool ?? false
            let resultData = GameResultData(won: won)
            displayStatus[game.id] = .completed(resultData)
            updateGameData(game: game, date: date, data: resultData.toGameData(gameId: game.id))
            return true
        } else {
            displayStatus[game.id] = .incomplete
            let gameData = GameData(
                gameId: game.id,
                isAvailable: true,
                isCompleted: false,
                isWon: false,
                lastChecked: Date()
            )
            updateGameData(game: game, date: date, data: gameData)
            return false
        }
    }

    func checkCompletion(for game: Game) {
        Task {
            let json = await evaluateCompletionScript(for: game)
            await MainActor.run {
                processCompletionResult(game: game, json: json, reason: "Single check")
            }
        }
    }

    /// Called when user exits a game - checks completion and retries once if needed
    func onGameExit(game: Game) {
        print("🎮 [\(game.name)] Game exit - checking completion")
        debugLogger.log(game: game, entry: DebugLogEntry(
            type: .stateChange, reason: "Game exit", summary: "User left game, checking completion"
        ))
        checkCompletion(for: game)

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if self.displayStatus[game.id] != .unavailable,
                   case .completed = self.displayStatus[game.id] {
                    return
                }
                self.checkCompletion(for: game)
            }
        }
    }

    /// Recheck completion status without reloading
    func recheckCompletion(for game: Game) {
        onGameExit(game: game)
    }

    func markLoaded(game: Game) {
        prefetchState[game.id] = .waitingForJS

        debugLogger.log(game: game, entry: DebugLogEntry(
            type: .response,
            reason: "Page loaded",
            summary: "WebView finished loading",
            details: ["URL": webViews[game.id]?.url?.absoluteString ?? "unknown"]
        ))

        // Initial delay for JS rendering (Ribbit needs longer)
        let initialDelay: UInt64 = game == .ribbit ? 5 : 1
        Task {
            try? await Task.sleep(nanoseconds: initialDelay * 1_000_000_000)
            await MainActor.run {
                self.prefetchState[game.id] = .checkingCompletion
                self.saveDebugData(for: game)
            }
            // Poll once per second for up to 5 checks
            var unchangedCount = 0
            var lastHash: Int? = nil
            let maxChecks = 5

            for check in 1...maxChecks {
                let json = await self.evaluateCompletionScript(for: game)
                let currentHash = await self.getPageContentHash(for: game)

                let completed = await MainActor.run {
                    self.processCompletionResult(
                        game: game,
                        json: json,
                        reason: "Polling check \(check)/\(maxChecks)"
                    )
                }

                if completed {
                    print("✅ [\(game.name)] Completed on check \(check)")
                    break
                }

                // Track page content stability
                if let hash = currentHash, hash == lastHash {
                    unchangedCount += 1
                } else {
                    unchangedCount = 0
                }
                lastHash = currentHash

                // If page hasn't changed for 3 consecutive checks, stop polling
                if unchangedCount >= 2 {
                    print("⏹ [\(game.name)] Page stable for 3 checks, marking incomplete")
                    await MainActor.run {
                        self.debugLogger.log(game: game, entry: DebugLogEntry(
                            type: .stateChange,
                            reason: "Early exit",
                            summary: "Page unchanged for 3 consecutive checks, ending poll"
                        ))
                    }
                    break
                }

                if check < maxChecks {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }

            await MainActor.run {
                self.prefetchState[game.id] = .ready
            }
        }
    }

    func markUnavailable(game: Game) {
        let date = currentDates[game.id] ?? Date()
        displayStatus[game.id] = .unavailable
        prefetchState[game.id] = .ready

        let gameData = GameData(
            gameId: game.id,
            isAvailable: false,
            isCompleted: false,
            isWon: false,
            lastChecked: Date()
        )
        updateGameData(game: game, date: date, data: gameData)
    }

    private func saveDebugData(for game: Game) {
        guard let webView = webViews[game.id] else {
            print("📄 [\(game.name)] No webview found")
            return
        }

        print("📄 [\(game.name)] Saving debug data...")

        let gameDir = debugDirectory
            .appendingPathComponent(game.source.displayName)
            .appendingPathComponent(game.name)

        do {
            try FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)
        } catch {
            print("📄 [\(game.name)] Error creating directory: \(error)")
            return
        }

        let localStorageScript = """
        (function() {
            var data = {};
            for (var i = 0; i < localStorage.length; i++) {
                var key = localStorage.key(i);
                try {
                    var value = localStorage.getItem(key);
                    try { data[key] = JSON.parse(value); } catch(e) { data[key] = value; }
                } catch(e) { data[key] = "[Error reading value]"; }
            }
            return JSON.stringify(data, null, 2);
        })();
        """

        // Capture all three pieces of data, then log a single debug entry
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] htmlResult, _ in
            guard let self = self else { return }
            let html = htmlResult as? String

            self.webViews[game.id]?.evaluateJavaScript("document.body.innerText") { bodyResult, _ in
                let bodyText = bodyResult as? String

                self.webViews[game.id]?.evaluateJavaScript(localStorageScript) { storageResult, _ in
                    let localStorage = storageResult as? String

                    // Write to disk
                    if let html = html {
                        try? html.write(to: gameDir.appendingPathComponent("page.html"), atomically: true, encoding: .utf8)
                    }
                    if let bodyText = bodyText {
                        try? bodyText.write(to: gameDir.appendingPathComponent("body.txt"), atomically: true, encoding: .utf8)
                    }
                    if let localStorage = localStorage {
                        try? localStorage.write(to: gameDir.appendingPathComponent("localStorage.json"), atomically: true, encoding: .utf8)
                    }

                    // Log to debug logger with all captured data
                    Task { @MainActor in
                        var details: [String: String] = [:]
                        details["URL"] = self.webViews[game.id]?.url?.absoluteString ?? "unknown"
                        if let html = html {
                            details["HTML"] = html
                        }
                        if let bodyText = bodyText {
                            details["Body Text"] = bodyText
                        }
                        if let localStorage = localStorage {
                            details["localStorage"] = localStorage
                        }

                        self.debugLogger.log(game: game, entry: DebugLogEntry(
                            type: .debugCapture,
                            reason: "Page snapshot",
                            summary: "Captured HTML (\(html?.count ?? 0) chars), body (\(bodyText?.count ?? 0) chars), localStorage",
                            details: details
                        ))
                    }
                }
            }
        }
    }

    func markFailed(game: Game) {
        prefetchState[game.id] = .failed
        debugLogger.log(game: game, entry: DebugLogEntry(
            type: .stateChange, reason: "Load failed", summary: "WebView navigation failed"
        ))
    }
}

private class PrefetchCoordinator: NSObject, WKNavigationDelegate {
    weak var manager: GamePrefetchManager?
    let game: Game
    private var loadStartTime: Date?
    private var originalRequestURL: URL?

    init(manager: GamePrefetchManager, game: Game) {
        self.manager = manager
        self.game = game
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadStartTime = Date()
        originalRequestURL = webView.url
        print("🔄 [\(game.name)] Started provisional navigation")
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        let newURL = webView.url?.absoluteString ?? "unknown"
        print("↪️ [\(game.name)] Received redirect to: \(newURL)")

        // Detect if Big Crossword redirected away (unavailable)
        if game.canBeUnavailable,
           let original = originalRequestURL,
           let current = webView.url {
            let originalPath = original.path
            let currentPath = current.path

            // If we requested big crossword but got redirected to a different puzzle
            if originalPath.contains("/crossword/big") && !currentPath.contains("/crossword/big") {
                print("⚠️ [\(game.name)] Detected redirect away from Big Crossword - game unavailable")
                Task { @MainActor in
                    self.manager?.markUnavailable(game: self.game)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("📥 [\(game.name)] Committed navigation, loading content...")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let elapsed = loadStartTime.map { Date().timeIntervalSince($0) } ?? 0
        print("✅ [\(game.name)] Finished loading in \(String(format: "%.2f", elapsed))s - URL: \(webView.url?.absoluteString ?? "unknown")")
        Task { @MainActor in
            manager?.markLoaded(game: game)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        print("❌ [\(game.name)] Navigation failed: \(error.localizedDescription)")
        print("❌ [\(game.name)] Error domain: \(nsError.domain), code: \(nsError.code)")
        if let failingURL = nsError.userInfo[NSURLErrorFailingURLStringErrorKey] {
            print("❌ [\(game.name)] Failing URL: \(failingURL)")
        }
        Task { @MainActor in
            manager?.markFailed(game: game)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        print("❌ [\(game.name)] Provisional navigation failed: \(error.localizedDescription)")
        print("❌ [\(game.name)] Error domain: \(nsError.domain), code: \(nsError.code)")
        if let failingURL = nsError.userInfo[NSURLErrorFailingURLStringErrorKey] {
            print("❌ [\(game.name)] Failing URL: \(failingURL)")
        }

        // Check if this is a 404 for an unavailable game
        if game.canBeUnavailable && nsError.code == NSURLErrorResourceUnavailable {
            Task { @MainActor in
                self.manager?.markUnavailable(game: self.game)
            }
            return
        }

        Task { @MainActor in
            manager?.markFailed(game: game)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            print("🔍 [\(game.name)] Navigation request: \(navigationAction.navigationType.rawValue) -> \(url.absoluteString)")
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let httpResponse = navigationResponse.response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            let url = httpResponse.url?.absoluteString ?? "unknown"

            Task { @MainActor in
                self.manager?.debugLogger.log(game: self.game, entry: DebugLogEntry(
                    type: .response,
                    reason: "HTTP response",
                    summary: "HTTP \(statusCode) from \(httpResponse.url?.host ?? "unknown")",
                    details: ["Status": "\(statusCode)", "URL": url]
                ))
            }

            if statusCode >= 400 {
                print("⚠️ [\(game.name)] HTTP error: \(statusCode) for \(url)")
                if statusCode == 404 && game.canBeUnavailable {
                    Task { @MainActor in
                        self.manager?.markUnavailable(game: self.game)
                    }
                }
            } else {
                print("📡 [\(game.name)] HTTP \(statusCode) for \(httpResponse.url?.host ?? "unknown")")
            }
        }
        decisionHandler(.allow)
    }
}
