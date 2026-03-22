import Foundation
import SwiftData

/// Represents completion data for a single game on a specific day
struct GameData: Codable, Equatable {
    var gameId: String              // Game.rawValue (e.g., "wordle", "crosswordBig")
    var isAvailable: Bool = true    // false if game doesn't exist for this date
    var isCompleted: Bool = false
    var isWon: Bool = false
    var guesses: Int?               // Wordle-specific
    var mistakes: Int?              // Connections-specific
    var streak: Int?                // Puzzmo-specific
    var maxStreak: Int?
    var totalPlayed: Int?
    var lastChecked: Date?
}

/// Represents a single day with all game statuses
@Model
final class GameDay {
    @Attribute(.unique) var dateString: String  // "yyyy-MM-dd" as primary key
    var date: Date
    var games: [GameData]                       // One entry per game type

    init(date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateString = formatter.string(from: date)
        self.date = Calendar.current.startOfDay(for: date)

        // Initialize with all games
        self.games = Game.allCases.map { game in
            GameData(gameId: game.id)
        }
    }

    func gameData(for game: Game) -> GameData? {
        games.first { $0.gameId == game.id }
    }

    func updateGame(_ game: Game, with data: GameData) {
        if let index = games.firstIndex(where: { $0.gameId == game.id }) {
            games[index] = data
        }
    }
}
