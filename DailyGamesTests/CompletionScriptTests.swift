import XCTest
import JavaScriptCore
@testable import DailyGames

final class CompletionScriptTests: XCTestCase {

    private var sampleDataURL: URL {
        // Try multiple paths to find SampleData
        let possiblePaths = [
            // From source file location (command line builds)
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("DailyGames/SampleData"),
            // From SRCROOT environment variable (Xcode builds)
            ProcessInfo.processInfo.environment["SRCROOT"].map {
                URL(fileURLWithPath: $0).appendingPathComponent("DailyGames/SampleData")
            },
            // Hardcoded fallback for this project
            URL(fileURLWithPath: "/Users/markschmidt/Documents/Daily-games/DailyGames/SampleData")
        ].compactMap { $0 }

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        // Default to first path even if it doesn't exist (will fail with clear error)
        return possiblePaths[0]
    }

    private var scriptsURL: URL {
        // Try multiple paths to find CompletionScripts
        let possiblePaths = [
            // From source file location (command line builds)
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("DailyGames/Resources/CompletionScripts"),
            // From SRCROOT environment variable (Xcode builds)
            ProcessInfo.processInfo.environment["SRCROOT"].map {
                URL(fileURLWithPath: $0).appendingPathComponent("DailyGames/Resources/CompletionScripts")
            },
            // Hardcoded fallback for this project
            URL(fileURLWithPath: "/Users/markschmidt/Documents/Daily-games/DailyGames/Resources/CompletionScripts")
        ].compactMap { $0 }

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        return possiblePaths[0]
    }

    // MARK: - Test Helpers

    private func loadLocalStorage(for game: Game, completed: Bool) -> [String: Any]? {
        let folder = completed ? "DailyGamesComplete" : "DailyGamesIncomplete"
        let gamePath: String

        switch game {
        case .wordle:
            gamePath = "NYT Games/Wordle"
        case .connections:
            gamePath = "NYT Games/Connections"
        case .bracketCity:
            gamePath = "The Atlantic/Bracket City"
        case .raddle:
            gamePath = "Raddle/Raddle"
        case .crosswordMini:
            gamePath = "Puzzmo/Mini Crossword"
        case .crossword:
            gamePath = "Puzzmo/Crossword"
        case .crosswordBig:
            gamePath = "Puzzmo/Big Crossword"
        case .ribbit:
            gamePath = "Puzzmo/Ribbit"
        case .circuits:
            gamePath = "Puzzmo/Circuits"
        case .reallyBadChess:
            gamePath = "Puzzmo/Really Bad Chess"
        }

        let url = sampleDataURL
            .appendingPathComponent(folder)
            .appendingPathComponent(gamePath)
            .appendingPathComponent("localStorage.json")

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private func loadBodyText(for game: Game, completed: Bool) -> String? {
        let folder = completed ? "DailyGamesComplete" : "DailyGamesIncomplete"
        let gamePath: String

        switch game {
        case .wordle:
            gamePath = "NYT Games/Wordle"
        case .connections:
            gamePath = "NYT Games/Connections"
        case .bracketCity:
            gamePath = "The Atlantic/Bracket City"
        case .raddle:
            gamePath = "Raddle/Raddle"
        case .crosswordMini:
            gamePath = "Puzzmo/Mini Crossword"
        case .crossword:
            gamePath = "Puzzmo/Crossword"
        case .crosswordBig:
            gamePath = "Puzzmo/Big Crossword"
        case .ribbit:
            gamePath = "Puzzmo/Ribbit"
        case .circuits:
            gamePath = "Puzzmo/Circuits"
        case .reallyBadChess:
            gamePath = "Puzzmo/Really Bad Chess"
        }

        let url = sampleDataURL
            .appendingPathComponent(folder)
            .appendingPathComponent(gamePath)
            .appendingPathComponent("body.txt")

        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func loadPageHTML(for game: Game, completed: Bool) -> String? {
        let folder = completed ? "DailyGamesComplete" : "DailyGamesIncomplete"
        let gamePath: String

        switch game {
        case .wordle:
            gamePath = "NYT Games/Wordle"
        case .connections:
            gamePath = "NYT Games/Connections"
        case .bracketCity:
            gamePath = "The Atlantic/Bracket City"
        case .raddle:
            gamePath = "Raddle/Raddle"
        case .crosswordMini:
            gamePath = "Puzzmo/Mini Crossword"
        case .crossword:
            gamePath = "Puzzmo/Crossword"
        case .crosswordBig:
            gamePath = "Puzzmo/Big Crossword"
        case .ribbit:
            gamePath = "Puzzmo/Ribbit"
        case .circuits:
            gamePath = "Puzzmo/Circuits"
        case .reallyBadChess:
            gamePath = "Puzzmo/Really Bad Chess"
        }

        let url = sampleDataURL
            .appendingPathComponent(folder)
            .appendingPathComponent(gamePath)
            .appendingPathComponent("page.html")

        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func runCompletionScript(for game: Game, localStorage: [String: Any], bodyText: String, innerHTML: String, url: String, mockDate: String = "2026-03-04") -> (completed: Bool, won: Bool)? {
        guard let context = JSContext() else {
            XCTFail("Failed to create JSContext")
            return nil
        }

        // Setup exception handler
        context.exceptionHandler = { context, exception in
            print("JS Exception: \(exception?.toString() ?? "unknown")")
        }

        // Mock the Date object to return a fixed date
        let dateSetup = """
        var _RealDate = Date;
        var _mockDate = "\(mockDate)";
        Date = function() {
            return {
                toLocaleDateString: function(locale) {
                    if (locale === 'en-CA') return _mockDate;
                    return _mockDate;
                }
            };
        };
        """

        // Create mock localStorage
        let localStorageSetup = """
        var _localStorageData = \(serializeToJSON(localStorage));
        var localStorage = {
            _data: _localStorageData,
            length: Object.keys(_localStorageData).length,
            key: function(i) {
                return Object.keys(this._data)[i] || null;
            },
            getItem: function(key) {
                var val = this._data[key];
                if (val === undefined) return null;
                if (typeof val === 'object') return JSON.stringify(val);
                return val;
            },
            setItem: function(key, value) {
                this._data[key] = value;
            },
            removeItem: function(key) {
                delete this._data[key];
            },
            clear: function() {
                this._data = {};
            }
        };
        """

        // Create mock document
        let escapedBodyText = escapeForJS(bodyText)
        let escapedInnerHTML = escapeForJS(innerHTML)
        let documentSetup = """
        var document = {
            body: {
                innerText: "\(escapedBodyText)",
                innerHTML: "\(escapedInnerHTML)"
            }
        };
        """

        // Create mock window with location
        let windowSetup = """
        var window = {
            location: {
                href: "\(url)"
            }
        };
        """

        // Load script from source directory
        let scriptPath = scriptsURL.appendingPathComponent("\(game.completionScriptName).js")

        guard let script = try? String(contentsOf: scriptPath, encoding: .utf8) else {
            XCTFail("Failed to load completion script: \(game.completionScriptName).js from \(scriptPath.path)")
            return nil
        }

        // Run setup and script
        context.evaluateScript(dateSetup)
        context.evaluateScript(localStorageSetup)
        context.evaluateScript(documentSetup)
        context.evaluateScript(windowSetup)

        guard let result = context.evaluateScript(script)?.toString(),
              let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse script result")
            return nil
        }

        let completed = json["completed"] as? Bool ?? false
        let won = json["won"] as? Bool ?? false
        return (completed, won)
    }

    private func serializeToJSON(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    private func escapeForJS(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    // MARK: - Wordle Tests

    func testWordleComplete() {
        let localStorage = loadLocalStorage(for: .wordle, completed: true) ?? [:]
        let bodyText = loadBodyText(for: .wordle, completed: true) ?? ""
        let innerHTML = loadPageHTML(for: .wordle, completed: true) ?? ""

        let result = runCompletionScript(
            for: .wordle,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.nytimes.com/games/wordle/index.html"
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.completed ?? false, "Wordle should be detected as completed")
        XCTAssertTrue(result?.won ?? false, "Wordle should be detected as won")
    }

    func testWordleIncomplete() {
        let localStorage = loadLocalStorage(for: .wordle, completed: false) ?? [:]
        let bodyText = loadBodyText(for: .wordle, completed: false) ?? ""
        let innerHTML = loadPageHTML(for: .wordle, completed: false) ?? ""

        let result = runCompletionScript(
            for: .wordle,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.nytimes.com/games/wordle/index.html"
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.completed ?? true, "Wordle should be detected as incomplete")
    }

    // MARK: - Connections Tests

    func testConnectionsComplete() {
        let localStorage = loadLocalStorage(for: .connections, completed: true) ?? [:]
        let bodyText = loadBodyText(for: .connections, completed: true) ?? ""
        let innerHTML = loadPageHTML(for: .connections, completed: true) ?? ""

        let result = runCompletionScript(
            for: .connections,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.nytimes.com/games/connections"
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.completed ?? false, "Connections should be detected as completed")
    }

    func testConnectionsIncomplete() {
        let localStorage = loadLocalStorage(for: .connections, completed: false) ?? [:]
        let bodyText = loadBodyText(for: .connections, completed: false) ?? ""
        let innerHTML = loadPageHTML(for: .connections, completed: false) ?? ""

        let result = runCompletionScript(
            for: .connections,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.nytimes.com/games/connections"
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.completed ?? true, "Connections should be detected as incomplete")
    }

    // MARK: - Bracket City Tests

    func testBracketCityComplete() {
        let localStorage = loadLocalStorage(for: .bracketCity, completed: true) ?? [:]
        let bodyText = loadBodyText(for: .bracketCity, completed: true) ?? ""
        let innerHTML = loadPageHTML(for: .bracketCity, completed: true) ?? ""

        let result = runCompletionScript(
            for: .bracketCity,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.theatlantic.com/games/bracket-city/"
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.completed ?? false, "Bracket City should be detected as completed")
    }

    func testBracketCityIncomplete() {
        let localStorage = loadLocalStorage(for: .bracketCity, completed: false) ?? [:]
        let bodyText = loadBodyText(for: .bracketCity, completed: false) ?? ""
        let innerHTML = loadPageHTML(for: .bracketCity, completed: false) ?? ""

        let result = runCompletionScript(
            for: .bracketCity,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.theatlantic.com/games/bracket-city/"
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.completed ?? true, "Bracket City should be detected as incomplete")
    }

    // MARK: - Raddle Tests

    func testRaddleComplete() {
        let localStorage = loadLocalStorage(for: .raddle, completed: true) ?? [:]
        let bodyText = loadBodyText(for: .raddle, completed: true) ?? ""
        let innerHTML = loadPageHTML(for: .raddle, completed: true) ?? ""

        let result = runCompletionScript(
            for: .raddle,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://raddle.quest"
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.completed ?? false, "Raddle should be detected as completed")
    }

    func testRaddleIncomplete() {
        let localStorage = loadLocalStorage(for: .raddle, completed: false) ?? [:]
        let bodyText = loadBodyText(for: .raddle, completed: false) ?? ""
        let innerHTML = loadPageHTML(for: .raddle, completed: false) ?? ""

        let result = runCompletionScript(
            for: .raddle,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://raddle.quest"
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.completed ?? true, "Raddle should be detected as incomplete")
    }

    // MARK: - Puzzmo Tests

    func testRibbitComplete() {
        let localStorage = loadLocalStorage(for: .ribbit, completed: true) ?? [:]
        let bodyText = loadBodyText(for: .ribbit, completed: true) ?? ""
        let innerHTML = loadPageHTML(for: .ribbit, completed: true) ?? ""

        let result = runCompletionScript(
            for: .ribbit,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.puzzmo.com/puzzle/2026-03-04/ribbit"
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.completed ?? false, "Ribbit should be detected as completed")
    }

    func testRibbitIncomplete() {
        let localStorage = loadLocalStorage(for: .ribbit, completed: false) ?? [:]
        let bodyText = loadBodyText(for: .ribbit, completed: false) ?? ""
        let innerHTML = loadPageHTML(for: .ribbit, completed: false) ?? ""

        let result = runCompletionScript(
            for: .ribbit,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.puzzmo.com/puzzle/2026-03-04/ribbit"
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.completed ?? true, "Ribbit should be detected as incomplete")
    }

    func testCircuitsComplete() {
        let localStorage = loadLocalStorage(for: .circuits, completed: true) ?? [:]
        let bodyText = loadBodyText(for: .circuits, completed: true) ?? ""
        let innerHTML = loadPageHTML(for: .circuits, completed: true) ?? ""

        let result = runCompletionScript(
            for: .circuits,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.puzzmo.com/puzzle/2026-03-04/circuits"
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.completed ?? false, "Circuits should be detected as completed")
    }

    func testCircuitsIncomplete() {
        let localStorage = loadLocalStorage(for: .circuits, completed: false) ?? [:]
        let bodyText = loadBodyText(for: .circuits, completed: false) ?? ""
        let innerHTML = loadPageHTML(for: .circuits, completed: false) ?? ""

        let result = runCompletionScript(
            for: .circuits,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.puzzmo.com/puzzle/2026-03-04/circuits"
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.completed ?? true, "Circuits should be detected as incomplete")
    }

    func testCrosswordMiniComplete() {
        let localStorage = loadLocalStorage(for: .crosswordMini, completed: true) ?? [:]
        let bodyText = loadBodyText(for: .crosswordMini, completed: true) ?? ""
        let innerHTML = loadPageHTML(for: .crosswordMini, completed: true) ?? ""

        let result = runCompletionScript(
            for: .crosswordMini,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.puzzmo.com/puzzle/2026-03-04/crossword/mini"
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.completed ?? false, "Mini Crossword should be detected as completed")
    }

    func testCrosswordMiniIncomplete() {
        let localStorage = loadLocalStorage(for: .crosswordMini, completed: false) ?? [:]
        let bodyText = loadBodyText(for: .crosswordMini, completed: false) ?? ""
        let innerHTML = loadPageHTML(for: .crosswordMini, completed: false) ?? ""

        let result = runCompletionScript(
            for: .crosswordMini,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.puzzmo.com/puzzle/2026-03-04/crossword/mini"
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.completed ?? true, "Mini Crossword should be detected as incomplete")
    }

    func testCrosswordComplete() {
        let localStorage = loadLocalStorage(for: .crossword, completed: true) ?? [:]
        let bodyText = loadBodyText(for: .crossword, completed: true) ?? ""
        let innerHTML = loadPageHTML(for: .crossword, completed: true) ?? ""

        let result = runCompletionScript(
            for: .crossword,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.puzzmo.com/puzzle/2026-03-04/crossword"
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.completed ?? false, "Crossword should be detected as completed")
    }

    func testCrosswordIncomplete() {
        let localStorage = loadLocalStorage(for: .crossword, completed: false) ?? [:]
        let bodyText = loadBodyText(for: .crossword, completed: false) ?? ""
        let innerHTML = loadPageHTML(for: .crossword, completed: false) ?? ""

        let result = runCompletionScript(
            for: .crossword,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.puzzmo.com/puzzle/2026-03-04/crossword"
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.completed ?? true, "Crossword should be detected as incomplete")
    }

    func testCrosswordBigComplete() {
        let localStorage = loadLocalStorage(for: .crosswordBig, completed: true) ?? [:]
        let bodyText = loadBodyText(for: .crosswordBig, completed: true) ?? ""
        let innerHTML = loadPageHTML(for: .crosswordBig, completed: true) ?? ""

        // Big crossword sample data was captured on 2026-03-03 (biweekly puzzle)
        let result = runCompletionScript(
            for: .crosswordBig,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.puzzmo.com/puzzle/2026-03-03/crossword/big",
            mockDate: "2026-03-03"
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.completed ?? false, "Big Crossword should be detected as completed")
    }

    func testCrosswordBigIncomplete() {
        let localStorage = loadLocalStorage(for: .crosswordBig, completed: false) ?? [:]
        let bodyText = loadBodyText(for: .crosswordBig, completed: false) ?? ""
        let innerHTML = loadPageHTML(for: .crosswordBig, completed: false) ?? ""

        let result = runCompletionScript(
            for: .crosswordBig,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.puzzmo.com/puzzle/2026-03-04/crossword/big"
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.completed ?? true, "Big Crossword should be detected as incomplete")
    }

    func testReallyBadChessComplete() {
        let localStorage = loadLocalStorage(for: .reallyBadChess, completed: true) ?? [:]
        let bodyText = loadBodyText(for: .reallyBadChess, completed: true) ?? ""
        let innerHTML = loadPageHTML(for: .reallyBadChess, completed: true) ?? ""

        let result = runCompletionScript(
            for: .reallyBadChess,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.puzzmo.com/puzzle/2026-03-04/really-bad-chess"
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.completed ?? false, "Really Bad Chess should be detected as completed")
    }

    func testReallyBadChessIncomplete() {
        let localStorage = loadLocalStorage(for: .reallyBadChess, completed: false) ?? [:]
        let bodyText = loadBodyText(for: .reallyBadChess, completed: false) ?? ""
        let innerHTML = loadPageHTML(for: .reallyBadChess, completed: false) ?? ""

        let result = runCompletionScript(
            for: .reallyBadChess,
            localStorage: localStorage,
            bodyText: bodyText,
            innerHTML: innerHTML,
            url: "https://www.puzzmo.com/puzzle/2026-03-04/really-bad-chess"
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.completed ?? true, "Really Bad Chess should be detected as incomplete")
    }
}
