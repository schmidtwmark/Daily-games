import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(Game.groupedBySource, id: \.source) { section in
                    Section(section.source) {
                        ForEach(section.games) { game in
                            NavigationLink(value: game) {
                                GameRow(game: game)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Daily Games")
            .navigationDestination(for: Game.self) { game in
                GamePlayerView(game: game)
            }
        }
    }
}

private struct GameRow: View {
    let game: Game

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: game.systemImage)
                .font(.title2)
                .foregroundStyle(game.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(game.name)
                    .font(.body.weight(.medium))
                if let subtitle = game.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
