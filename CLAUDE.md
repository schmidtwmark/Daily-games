# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build for Debug
xcodebuild build -scheme DailyGames -configuration Debug

# Build for Release
xcodebuild build -scheme DailyGames -configuration Release

# Archive for App Store/Distribution
xcodebuild archive -scheme DailyGames -archivePath "DailyGames.xcarchive"
```

Or open `DailyGames.xcodeproj` in Xcode and use Cmd+B to build, Cmd+R to run.

## Project Overview

Daily Games is a native iOS app (iOS 17.0+) built with SwiftUI that serves as a launcher for web-based daily puzzle games. The app embeds games from The Atlantic, Raddle, NYT Games, and Puzzmo using WKWebView with prefetching and completion detection.

**No external dependencies** - pure Swift/SwiftUI with WebKit.

## Architecture

```
DailyGames/
├── DailyGamesApp.swift      # App entry point, injects GamePrefetchManager
├── Models/
│   └── Game.swift           # Source and Game enums + completion scripts
├── Services/
│   └── GamePrefetchManager.swift  # Prefetching + completion detection
└── Views/
    ├── ContentView.swift    # Main list view with completion indicators
    ├── GamePlayerView.swift # Game player with date picker
    └── WebView.swift        # WKWebView wrapper with WebViewModel
```

**Key patterns:**
- `Source` enum defines game sources (The Atlantic, Raddle, NYT Games, Puzzmo)
- `Game` enum defines all games with computed properties + `completionScript` JavaScript
- `GamePrefetchManager` (EnvironmentObject) preloads all games on launch and detects completion via JavaScript injection
- `WebViewModel` (ObservableObject) manages webview state (loading, progress, navigation)
- `WebView` wraps WKWebView via UIViewRepresentable
- All games support date navigation for viewing historical puzzles via date picker

## Adding New Games

Edit `Models/Game.swift`:

1. Add a new case to the `Game` enum
2. If new source, add case to `Source` enum
3. Add the new case to each computed property's switch:
   - `source` - which Source it belongs to
   - `name` - display name
   - `subtitle` - optional (e.g., "Biweekly")
   - `systemImage` - SF Symbol name
   - `color` - SwiftUI color
   - `baseURL` - game URL (use `{date}` placeholder for Puzzmo games)
   - `completionScriptName` - name of .js file in CompletionScripts/
   - Update `url(for:)` to generate correct date URL format for the game
