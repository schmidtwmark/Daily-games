import SwiftUI

struct Game: Identifiable, Hashable {
    let id: String
    let name: String
    let source: String
    let subtitle: String?
    let systemImage: String
    let color: Color
    private let baseURL: String
    private let usesTodayDate: Bool

    init(
        id: String,
        name: String,
        source: String,
        subtitle: String? = nil,
        systemImage: String,
        color: Color,
        baseURL: String,
        usesTodayDate: Bool = false
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.color = color
        self.baseURL = baseURL
        self.usesTodayDate = usesTodayDate
    }

    var url: URL {
        if usesTodayDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())
            return URL(string: baseURL.replacingOccurrences(of: "{date}", with: today))!
        }
        return URL(string: baseURL)!
    }

    // MARK: - Hashable

    static func == (lhs: Game, rhs: Game) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Game catalog

    static let allGames: [Game] = [
        // The Atlantic
        Game(
            id: "bracket-city",
            name: "Bracket City",
            source: "The Atlantic",
            systemImage: "trophy.fill",
            color: .red,
            baseURL: "https://www.theatlantic.com/games/bracket-city/"
        ),

        // Raddle
        Game(
            id: "raddle",
            name: "Raddle",
            source: "Raddle",
            systemImage: "circle.grid.3x3.fill",
            color: .purple,
            baseURL: "https://raddle.quest"
        ),

        // NYT Games
        Game(
            id: "wordle",
            name: "Wordle",
            source: "NYT Games",
            systemImage: "character.textbox",
            color: .green,
            baseURL: "https://www.nytimes.com/games/wordle/index.html"
        ),
        Game(
            id: "connections",
            name: "Connections",
            source: "NYT Games",
            systemImage: "square.grid.2x2.fill",
            color: .yellow,
            baseURL: "https://www.nytimes.com/games/connections"
        ),

        // Puzzmo
        Game(
            id: "crossword-mini",
            name: "Mini Crossword",
            source: "Puzzmo",
            systemImage: "grid",
            color: .blue,
            baseURL: "https://www.puzzmo.com/puzzle/{date}/crossword/mini",
            usesTodayDate: true
        ),
        Game(
            id: "crossword",
            name: "Crossword",
            source: "Puzzmo",
            systemImage: "grid",
            color: .blue,
            baseURL: "https://www.puzzmo.com/puzzle/{date}/crossword",
            usesTodayDate: true
        ),
        Game(
            id: "crossword-big",
            name: "Big Crossword",
            source: "Puzzmo",
            subtitle: "Biweekly",
            systemImage: "grid",
            color: .blue,
            baseURL: "https://www.puzzmo.com/puzzle/{date}/crossword/big",
            usesTodayDate: true
        ),
        Game(
            id: "ribbit",
            name: "Ribbit",
            source: "Puzzmo",
            systemImage: "leaf.fill",
            color: .mint,
            baseURL: "https://www.puzzmo.com/puzzle/{date}/ribbit",
            usesTodayDate: true
        ),
        Game(
            id: "circuits",
            name: "Circuits",
            source: "Puzzmo",
            systemImage: "bolt.fill",
            color: .orange,
            baseURL: "https://www.puzzmo.com/puzzle/{date}/circuits",
            usesTodayDate: true
        ),
        Game(
            id: "really-bad-chess",
            name: "Really Bad Chess",
            source: "Puzzmo",
            systemImage: "crown.fill",
            color: .brown,
            baseURL: "https://www.puzzmo.com/puzzle/{date}/really-bad-chess",
            usesTodayDate: true
        ),
    ]

    static var groupedBySource: [(source: String, games: [Game])] {
        let sourceOrder = ["The Atlantic", "Raddle", "NYT Games", "Puzzmo"]
        return sourceOrder.compactMap { source in
            let games = allGames.filter { $0.source == source }
            return games.isEmpty ? nil : (source: source, games: games)
        }
    }
}
