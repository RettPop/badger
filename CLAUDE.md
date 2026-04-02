# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SMatcher — a strategic match-3 puzzle game built with Flutter. Players swap adjacent tiles on a 4×5 grid to form groups of 3+ tiles sharing attributes (color, letter, badge value). Scoring uses attribute-based multipliers (color=1×, badge=2×, letter=3×, stacked when multiple attributes match). The game tracks an "optimum score" — the best possible move — and compares player performance against it.

## Build & Run Commands

```bash
flutter run -d chrome          # Run on web (primary target)
flutter run -d macos            # Run on macOS desktop
flutter test                    # Run all tests
flutter test test/game_state_test.dart  # Run a single test file
flutter analyze                 # Lint (uses flutter_lints)
```

Package name in pubspec.yaml is `smatcher`. Dart SDK constraint: `^3.11.0`.

## Architecture

Layered structure under `lib/`:

- **`domain/models/tile.dart`** — Immutable `Tile` model with 3 game attributes: `color`, `letter`, `value` (badge). Uses `copyWith` for position changes during swaps.
- **`domain/logic/game_state.dart`** — Core game engine as a `ChangeNotifier`. Handles board initialization, tile swapping, match detection (horizontal, vertical, both diagonals), scoring, optimum move calculation (brute-force all adjacent swaps), snapshot/hint modes, and session quality tracking.
- **`presentation/screens/game_screen.dart`** — Single screen: score header, board, bottom action bar (home, snapshot toggle, continue, board redraw with score penalty).
- **`presentation/widgets/board_widget.dart`** — Renders the grid using `Stack` + `AnimatedPositioned` for swap/refill animations. Manages tile selection state. Highlights user matches, optimum matches, and hint swap tiles.
- **`presentation/widgets/tile_widget.dart`** — Individual tile: colored rounded square with centered letter and a red circular badge (top-right) showing the value.

State flows through `ListenableBuilder` in `GameScreen` listening to `GameState`. No dependency injection or state management package — `GameState` is instantiated directly in `_GameScreenState`.

## Key Game Logic Details

- Match detection (`findMatchesInternal`) scans all 4 directions × 3 attributes, deduplicating via visited-set per direction+attribute. The `activeTiles` filter ensures only matches involving swapped tiles count for a move.
- `calculateMatchesScore` and `calculateMatchesInternalScore` deduplicate match groups by tile ID set, then merge attributes across groups sharing the same tiles. Multipliers sum: a group matching color+letter scores at (1+3)× the badge sum.
- Optimum calculation (`calculateOptimumScore`) simulates every legal adjacent swap and picks the highest-scoring one. This runs after every move and board init.
- Board redraw deducts the current optimum score as a penalty.
- Snapshot mode pauses after a successful swap to display matched and optimum tiles before processing removals.

## Testing

Tests are in `test/game_state_test.dart`. They use a `buildBoard` helper that creates a 5×4 board of fully unique tiles (no accidental matches), then applies specific tile overrides. Test imports use `package:badger/...` (the package is configured as `smatcher` in pubspec but test imports reference `badger`).
