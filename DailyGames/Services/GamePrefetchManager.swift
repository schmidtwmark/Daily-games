import SwiftUI
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

    init(won: Bool, guesses: Int? = nil, mistakes: Int? = nil, streak: Int? = nil, maxStreak: Int? = nil, totalPlayed: Int? = nil) {
        self.won = won
        self.guesses = guesses
        self.mistakes = mistakes
        self.streak = streak
        self.maxStreak = maxStreak
        self.totalPlayed = totalPlayed
    }

    init?(json: [String: Any]) {
        guard let completed = json["completed"] as? Bool, completed else { return nil }
        self.won = json["won"] as? Bool ?? false
        self.guesses = json["guesses"] as? Int
        self.mistakes = json["mistakes"] as? Int
        self.streak = json["streak"] as? Int
        self.maxStreak = json["maxStreak"] as? Int
        self.totalPlayed = json["totalPlayed"] as? Int
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

@MainActor
class GamePrefetchManager: ObservableObject {
    @Published var completionStatus: [String: CompletionStatus] = [:]
    @Published var prefetchState: [String: PrefetchState] = [:]

    private var webViews: [String: WKWebView] = [:]
    private var coordinators: [String: PrefetchCoordinator] = [:]
    private var currentDates: [String: Date] = [:]
    /// Tracks when each game was last fetched (date component only, not time)
    private var lastFetchDates: [String: Date] = [:]

    private let debugDirectory: URL
    private let calendar = Calendar.current

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        debugDirectory = docs.appendingPathComponent("Daily Games")

        print("📁 Debug directory: \(debugDirectory.path)")

        for game in Game.allCases {
            completionStatus[game.id] = .unknown
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

    /// Prefetch all games that haven't been fetched today
    func prefetchAll() {
        let today = calendar.startOfDay(for: Date())
        for game in Game.allCases {
            // Only prefetch if we haven't fetched today
            if let lastFetch = lastFetchDates[game.id],
               calendar.isDate(lastFetch, inSameDayAs: today) {
                print("📦 [\(game.name)] Using cached result from today")
                continue
            }
            prefetch(game: game, for: Date())
        }
    }

    func prefetch(game: Game, for date: Date) {
        prefetchState[game.id] = .fetching
        currentDates[game.id] = date
        lastFetchDates[game.id] = calendar.startOfDay(for: date)

        let webView = getOrCreateWebView(for: game)
        let url = game.url(for: date)
        print("🌐 [\(game.name)] Starting prefetch: \(url.absoluteString)")

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
            prefetch(game: game, for: date)
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

    func checkCompletion(for game: Game) {
        guard let webView = webViews[game.id] else { return }

        webView.evaluateJavaScript(game.completionScript) { [weak self] result, _ in
            guard let self = self else { return }

            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                let completed = json["completed"] as? Bool ?? false

                Task { @MainActor in
                    if completed, let resultData = GameResultData(json: json) {
                        self.completionStatus[game.id] = .completed(resultData)
                    } else if completed {
                        // Fallback for scripts that don't return full data
                        let won = json["won"] as? Bool ?? false
                        self.completionStatus[game.id] = .completed(GameResultData(won: won))
                    } else {
                        self.completionStatus[game.id] = .incomplete
                    }
                }
            } else {
                Task { @MainActor in
                    self.completionStatus[game.id] = .unknown
                }
            }
        }
    }

    /// Recheck completion status without reloading - called when returning from a game
    func recheckCompletion(for game: Game) {
        checkCompletion(for: game)
    }

    func markLoaded(game: Game) {
        prefetchState[game.id] = .waitingForJS

        // Wait for JavaScript to fully render before checking completion
        // Ribbit has a longer completion animation
        let delaySeconds: UInt64 = game == .ribbit ? 8 : 3
        Task {
            try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
            await MainActor.run {
                self.prefetchState[game.id] = .checkingCompletion
                saveDebugData(for: game)
                checkCompletion(for: game)
                self.prefetchState[game.id] = .ready
            }
        }
    }

    private func saveDebugData(for game: Game) {
        guard let webView = webViews[game.id] else {
            print("📄 [\(game.name)] No webview found")
            return
        }

        print("📄 [\(game.name)] Saving debug data (after 3s delay)...")

        // Create directory structure: Daily Games/Source/Game/
        let gameDir = debugDirectory
            .appendingPathComponent(game.source.displayName)
            .appendingPathComponent(game.name)

        do {
            try FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)
            print("📄 [\(game.name)] Created directory: \(gameDir.path)")
        } catch {
            print("📄 [\(game.name)] Error creating directory: \(error)")
            return
        }

        // Save full HTML
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            if let error = error {
                print("📄 [\(game.name)] Error getting HTML: \(error)")
                return
            }

            if let html = result as? String {
                let htmlFile = gameDir.appendingPathComponent("page.html")
                do {
                    try html.write(to: htmlFile, atomically: true, encoding: .utf8)
                    print("📄 [\(game.name)] Saved HTML (\(html.count) chars)")
                } catch {
                    print("📄 [\(game.name)] Error writing HTML: \(error)")
                }
            }

            // Save body text
            self?.webViews[game.id]?.evaluateJavaScript("document.body.innerText") { result, _ in
                if let text = result as? String {
                    let textFile = gameDir.appendingPathComponent("body.txt")
                    try? text.write(to: textFile, atomically: true, encoding: .utf8)
                    print("📄 [\(game.name)] Saved body text (\(text.count) chars)")
                }
            }

            // Save localStorage as JSON
            let localStorageScript = """
            (function() {
                var data = {};
                for (var i = 0; i < localStorage.length; i++) {
                    var key = localStorage.key(i);
                    try {
                        var value = localStorage.getItem(key);
                        // Try to parse as JSON for better readability
                        try {
                            data[key] = JSON.parse(value);
                        } catch(e) {
                            data[key] = value;
                        }
                    } catch(e) {
                        data[key] = "[Error reading value]";
                    }
                }
                return JSON.stringify(data, null, 2);
            })();
            """

            self?.webViews[game.id]?.evaluateJavaScript(localStorageScript) { result, error in
                if let error = error {
                    print("📄 [\(game.name)] Error getting localStorage: \(error)")
                    return
                }

                if let jsonString = result as? String {
                    let storageFile = gameDir.appendingPathComponent("localStorage.json")
                    do {
                        try jsonString.write(to: storageFile, atomically: true, encoding: .utf8)
                        print("📄 [\(game.name)] Saved localStorage (\(jsonString.count) chars)")
                    } catch {
                        print("📄 [\(game.name)] Error writing localStorage: \(error)")
                    }
                }
            }
        }
    }

    func markFailed(game: Game) {
        prefetchState[game.id] = .failed
    }
}

private class PrefetchCoordinator: NSObject, WKNavigationDelegate {
    weak var manager: GamePrefetchManager?
    let game: Game
    private var loadStartTime: Date?

    init(manager: GamePrefetchManager, game: Game) {
        self.manager = manager
        self.game = game
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadStartTime = Date()
        print("🔄 [\(game.name)] Started provisional navigation")
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("↪️ [\(game.name)] Received redirect to: \(webView.url?.absoluteString ?? "unknown")")
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
            if statusCode >= 400 {
                print("⚠️ [\(game.name)] HTTP error: \(statusCode) for \(httpResponse.url?.absoluteString ?? "unknown")")
            } else {
                print("📡 [\(game.name)] HTTP \(statusCode) for \(httpResponse.url?.host ?? "unknown")")
            }
        }
        decisionHandler(.allow)
    }
}
