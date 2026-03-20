# Daily Games

A native iOS app that serves as a launcher for web-based daily puzzle games. Play your favorite puzzles from The Atlantic, Raddle, NYT Games, and Puzzmo all in one place.

## Features

- **Unified Game Launcher** - Access multiple daily puzzle games from a single app
- **Game Prefetching** - Games are preloaded for faster launch times
- **Completion Detection** - Visual indicators show which games you've completed
- **Date Navigation** - Play historical puzzles from any date
- **Native iOS Experience** - Built with SwiftUI for iOS 17.0+

## Supported Games

| Source | Games |
|--------|-------|
| **The Atlantic** | Bracket City |
| **Raddle** | Raddle |
| **NYT Games** | Wordle, Connections |
| **Puzzmo** | Mini Crossword, Crossword, Big Crossword (Biweekly), Ribbit, Circuits, Really Bad Chess |

## Requirements

- iOS 17.0+
- Xcode 15.0+

## Building

### Using Xcode

1. Open `DailyGames.xcodeproj` in Xcode
2. Select your target device or simulator
3. Press Cmd+R to build and run

### Using Command Line

```bash
# Build for Debug
xcodebuild build -scheme DailyGames -configuration Debug

# Build for Release
xcodebuild build -scheme DailyGames -configuration Release

# Archive for Distribution
xcodebuild archive -scheme DailyGames -archivePath "DailyGames.xcarchive"
```

## Project Structure

```
DailyGames/
├── DailyGamesApp.swift          # App entry point
├── Models/
│   └── Game.swift               # Source and Game enums
├── Services/
│   └── GamePrefetchManager.swift # Prefetching and completion detection
├── Views/
│   ├── ContentView.swift        # Main game list
│   ├── GamePlayerView.swift     # Game player with date picker
│   └── WebView.swift            # WKWebView wrapper
└── Resources/
    └── CompletionScripts/       # JavaScript for completion detection
        ├── wordle.js
        ├── connections.js
        ├── bracketCity.js
        ├── raddle.js
        └── puzzmo.js
```

## Architecture

The app uses a clean SwiftUI architecture:

- **Game/Source Enums** - Define all supported games with computed properties for URLs, colors, icons, and completion scripts
- **GamePrefetchManager** - An EnvironmentObject that preloads games on launch and detects completion via JavaScript injection
- **WebViewModel** - ObservableObject managing WebView state (loading, progress, navigation)
- **WebView** - UIViewRepresentable wrapper around WKWebView

## Adding New Games

See [CLAUDE.md](CLAUDE.md) for detailed instructions on adding new games to the app.

## Dependencies

None. The app uses only Apple frameworks:
- SwiftUI
- WebKit

## License

Private project.
