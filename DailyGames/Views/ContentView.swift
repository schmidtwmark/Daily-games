import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var prefetchManager: GamePrefetchManager

    var body: some View {
        NavigationStack {
            List {
                ForEach(Source.groupedGames, id: \.source) { section in
                    Section(section.source.displayName) {
                        ForEach(section.games) { game in
                            NavigationLink(value: game) {
                                GameRow(
                                    game: game,
                                    completionStatus: prefetchManager.completionStatus[game.id] ?? .unknown,
                                    prefetchState: prefetchManager.prefetchState[game.id] ?? .idle
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Daily Games")
            .navigationDestination(for: Game.self) { game in
                GamePlayerView(game: game)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        prefetchManager.refreshAll()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                prefetchManager.prefetchAll()
            }
        }
    }
}

private struct GameRow: View {
    let game: Game
    let completionStatus: CompletionStatus
    let prefetchState: PrefetchState

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

            Spacer()

            statusIndicator
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        // If still loading, show loading state
        if prefetchState.isLoading {
            HStack(spacing: 6) {
                Text(prefetchState.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView()
                    .scaleEffect(0.7)
            }
        } else if prefetchState == .failed {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
                .font(.title3)
        } else {
            // Ready state - show completion status
            switch completionStatus {
            case .completed(let data):
                HStack(spacing: 6) {
                    if let detail = detailText(for: data) {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: data.won ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(data.won ? .green : .red)
                        .font(.title3)
                }
            case .incomplete:
                HStack(spacing: 6) {
                    if let streak = streakText {
                        Text(streak)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            case .unknown:
                Image(systemName: "circle.dotted")
                    .foregroundStyle(.tertiary)
                    .font(.title3)
            }
        }
    }

    private func detailText(for data: GameResultData) -> String? {
        // Wordle: show guesses
        if let guesses = data.guesses {
            return "\(guesses)/6"
        }
        // Connections: show mistakes
        if let mistakes = data.mistakes {
            return mistakes == 0 ? "Perfect!" : "\(mistakes) mistake\(mistakes == 1 ? "" : "s")"
        }
        // Puzzmo: show streak
        if let streak = data.streak, streak > 0 {
            return "🔥 \(streak)"
        }
        return nil
    }

    private var streakText: String? {
        // For incomplete Puzzmo games, still show streak if available
        // This would require passing streak data even for incomplete games
        // For now, return nil
        return nil
    }
}
