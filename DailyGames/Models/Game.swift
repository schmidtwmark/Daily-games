import SwiftUI

enum Source: String, CaseIterable, Identifiable {
    case theAtlantic
    case raddle
    case nytGames
    case puzzmo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .theAtlantic: return "The Atlantic"
        case .raddle: return "Raddle"
        case .nytGames: return "NYT Games"
        case .puzzmo: return "Puzzmo"
        }
    }

    var games: [Game] {
        Game.allCases.filter { $0.source == self }
    }

    static var groupedGames: [(source: Source, games: [Game])] {
        allCases.compactMap { source in
            let games = source.games
            return games.isEmpty ? nil : (source: source, games: games)
        }
    }
}

enum Game: String, CaseIterable, Identifiable, Hashable {
    // The Atlantic
    case bracketCity

    // Raddle
    case raddle

    // NYT Games
    case wordle
    case connections

    // Puzzmo
    case crosswordMini
    case crossword
    case crosswordBig
    case ribbit
    case circuits
    case reallyBadChess

    var id: String { rawValue }

    var source: Source {
        switch self {
        case .bracketCity:
            return .theAtlantic
        case .raddle:
            return .raddle
        case .wordle, .connections:
            return .nytGames
        case .crosswordMini, .crossword, .crosswordBig, .ribbit, .circuits, .reallyBadChess:
            return .puzzmo
        }
    }

    var name: String {
        switch self {
        case .bracketCity: return "Bracket City"
        case .raddle: return "Raddle"
        case .wordle: return "Wordle"
        case .connections: return "Connections"
        case .crosswordMini: return "Mini Crossword"
        case .crossword: return "Crossword"
        case .crosswordBig: return "Big Crossword"
        case .ribbit: return "Ribbit"
        case .circuits: return "Circuits"
        case .reallyBadChess: return "Really Bad Chess"
        }
    }

    var subtitle: String? {
        switch self {
        case .crosswordBig: return "Biweekly"
        default: return nil
        }
    }

    var systemImage: String {
        switch self {
        case .bracketCity: return "trophy.fill"
        case .raddle: return "circle.grid.3x3.fill"
        case .wordle: return "character.textbox"
        case .connections: return "square.grid.2x2.fill"
        case .crosswordMini, .crossword, .crosswordBig: return "grid"
        case .ribbit: return "leaf.fill"
        case .circuits: return "bolt.fill"
        case .reallyBadChess: return "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .bracketCity: return .red
        case .raddle: return .purple
        case .wordle: return .green
        case .connections: return .yellow
        case .crosswordMini, .crossword, .crosswordBig: return .blue
        case .ribbit: return .mint
        case .circuits: return .orange
        case .reallyBadChess: return .brown
        }
    }

    private var baseURL: String {
        switch self {
        case .bracketCity:
            return "https://www.theatlantic.com/games/bracket-city/"
        case .raddle:
            return "https://raddle.quest"
        case .wordle:
            return "https://www.nytimes.com/games/wordle"
        case .connections:
            return "https://www.nytimes.com/games/connections"
        case .crosswordMini:
            return "https://www.puzzmo.com/puzzle/{date}/crossword/mini"
        case .crossword:
            return "https://www.puzzmo.com/puzzle/{date}/crossword"
        case .crosswordBig:
            return "https://www.puzzmo.com/puzzle/{date}/crossword/big"
        case .ribbit:
            return "https://www.puzzmo.com/puzzle/{date}/ribbit"
        case .circuits:
            return "https://www.puzzmo.com/puzzle/{date}/circuits"
        case .reallyBadChess:
            return "https://www.puzzmo.com/puzzle/{date}/really-bad-chess"
        }
    }

    var url: URL {
        url(for: Date())
    }

    func url(for date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        switch self {
        case .bracketCity:
            // Bracket City: ?date=yyyy-MM-dd
            return URL(string: "\(baseURL)?date=\(dateString)")!

        case .wordle, .connections:
            // NYT games: /yyyy-MM-dd appended to base URL
            return URL(string: "\(baseURL)/\(dateString)")!

        case .raddle:
            // Raddle: /yyyy/MM/dd format
            let year = Calendar.current.component(.year, from: date)
            let month = Calendar.current.component(.month, from: date)
            let day = Calendar.current.component(.day, from: date)
            return URL(string: String(format: "%@/%04d/%02d/%02d", baseURL, year, month, day))!

        case .crosswordMini, .crossword, .crosswordBig, .ribbit, .circuits, .reallyBadChess:
            // Puzzmo: {date} placeholder
            return URL(string: baseURL.replacingOccurrences(of: "{date}", with: dateString))!
        }
    }

    // MARK: - Completion Detection

    /// The name of the JavaScript file for completion detection
    var completionScriptName: String {
        switch self {
        case .wordle: return "wordle"
        case .connections: return "connections"
        case .bracketCity: return "bracketCity"
        case .raddle: return "raddle"
        case .crosswordMini, .crossword, .crosswordBig, .ribbit, .circuits, .reallyBadChess:
            return "puzzmo"
        }
    }

    /// Loads the completion detection script from the bundle
    var completionScript: String {
        guard let url = Bundle.main.url(forResource: completionScriptName, withExtension: "js", subdirectory: "CompletionScripts"),
              let script = try? String(contentsOf: url, encoding: .utf8) else {
            print("Failed to load completion script: \(completionScriptName).js")
            return "JSON.stringify({ completed: false, won: false });"
        }
        return script
    }

    // MARK: - Safe Area Configuration

    /// Whether this game needs bottom safe area inset
    var needsBottomSafeArea: Bool {
        switch self {
        case .bracketCity:
            return true
        default:
            return false
        }
    }
}
