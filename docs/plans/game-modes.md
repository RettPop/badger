# Game Modes — Implementation Plan

## Goal

Add six game modes to SMatcher, each varying tile mechanics, input methods, and scoring rules. A mode selection dialog (accessed via the Home icon) lets the user switch modes, resetting session stats. The active mode and its icon are displayed in the top bar where "MOVE CREDITS" currently appears.

## Scope

### In scope
- Game mode enum, model, and registration
- Mode-specific tile generation, gravity/fill, drag interactions, score drain
- Mode selection dialog UI
- Top bar updates (active mode display, conditional optimum/ratio hiding)
- Drag-to-adjacent as additional input for modes 1/2/3/6
- Tap-to-select + drag-to-any for mode 4
- Drag-only with snake path for mode 5
- Update README.md and GAMEDIS.md with new functionality
- Unit tests for new pure-Dart logic

### Out of scope
- Mode persistence across app restarts (future work)
- Chain-matching after gravity fill (explicitly excluded per spec)
- Game-over conditions

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| State management | Keep `ChangeNotifier` pattern — add `GameMode` enum to `GameState` | Consistent with existing architecture; no new packages needed |
| Mode behavior | Strategy pattern — each mode provides overrides for tile generation, match processing, input handling | Keeps `GameState` from becoming a giant switch-case; modes are testable in isolation |
| Drag interaction | Implement in `BoardWidget` using `GestureDetector`/`Listener` with `onPanStart/Update/End` | Works alongside existing tap handling; `AnimatedPositioned` already handles tile movement |
| Gravity fill (Mode 3) | Column-first drop, then closest-lateral fill with random tie-break | Per user specification |
| High Scores gen (Mode 2) | Retry loop in tile generation with attempt counter | Simple, bounded, no async complexity |
| Arcade timer (Mode 6) | `Timer.periodic` in `GameState`, paused during snapshot mode, floor score at 0 | Keeps timer logic in domain layer with existing session timer |

## Flutter-Specific Notes

- **Widget structure**: `BoardWidget` gains a `GestureDetector` wrapper for pan gestures. A new `ModeSelectionDialog` widget is added under `presentation/widgets/`.
- **State management**: `GameMode` enum and mode-specific behavior live in `domain/logic/`. `GameState` delegates to mode strategy for generation, fill, and input validation.
- **Animations**: Snake drag uses existing `AnimatedPositioned` — tiles shift as drag path updates. Return-to-origin also animates via the same mechanism.
- **Icons**: `Icons.spa` (Convenient), `Icons.emoji_events` (High Scores), `Icons.arrow_downward` (Drop Down), `Icons.swipe` (Simple Drag), `Icons.gesture` (Snake Drag), `Icons.timer` (Arcade).

---

## Detailed Design

### 1. Game Mode Model (`lib/domain/models/game_mode.dart`)

```dart
enum GameModeType { convenient, highScores, dropDown, simpleDrag, snakeDrag, arcade }
```

Each mode has:
- `name` — display name (e.g., "Convenient")
- `icon` — `IconData` for UI
- `calculatesOptimum` — bool (false for modes 4, 5)
- `usesGravity` — bool (true only for mode 3)
- `allowsDragToAny` — bool (true for modes 4, 5)
- `isSnakeDrag` — bool (true only for mode 5)
- `hasScoreDrain` — bool (true only for mode 6)
- `highScoreGeneration` — bool (true only for mode 2)

Implement as an extension on `GameModeType` or a companion class with a static map.

### 2. GameState Changes (`lib/domain/logic/game_state.dart`)

#### 2a. Mode property
- Add `GameModeType currentMode = GameModeType.convenient`
- Add `void setMode(GameModeType mode)` — sets mode, resets `totalScore = 0`, then calls `initializeBoard(resetSession: true)`. Note: the existing `initializeBoard` does NOT reset `totalScore`, so `setMode` must do it explicitly before calling `initializeBoard`.

#### 2b. Conditional optimum
- `calculateOptimumScore()`: skip (set `optimumScore = 0`) when `currentMode.calculatesOptimum == false`
- All optimum-related display values return 0/empty when optimum is disabled

#### 2c. Mode 2 — High Scores tile generation
New method `_generateTilesWithHighScoreConstraint(List<Point<int>> positions)`:
- After removing matched tiles, track the empty positions. For each attempt:
  1. Generate new random tiles for the empty positions and place them into `this.tiles`
  2. Run `calculateOptimumScore()` on the full 20-tile board
  3. If `optimumScore >= 50`, accept the result and stop
  4. If `optimumScore < 50`, **remove the just-generated tiles from `this.tiles`** and retry with fresh random tiles
- Retry up to 20 times (replacing only the new tiles each attempt)
- If all 20 partial attempts fail: **clear the entire `this.tiles` list** and regenerate all 20 tiles from scratch, checking optimum ≥ 50 each time, up to 20 full-board attempts
- If still fails: use the last generated result as-is
- Same logic applies to `initializeBoard()` when in mode 2

#### 2d. Mode 3 — Drop Down fill
New method `_applyGravityFill()`:
1. After removing matched tiles, identify empty positions
2. **Column drop**: For each column bottom-to-top, if a cell is empty, pull the nearest tile above it downward
3. **Lateral fill**: For remaining empty cells, find the closest filled tile by Manhattan distance from the empty cell to each candidate tile. On tie, choose randomly. Move that tile into the gap. Repeat until no empty cells remain or no more lateral moves are possible.
4. **Generate new tiles**: Fill any still-empty positions (which will be at the top or edges) with new random tiles
5. No chain-matching after fill — wait for next user move

Replace the current `processMatches` refill section with a mode-aware branch:
- Modes 1, 2, 4, 5, 6: current behavior (replace in-place)
- Mode 3: call `_applyGravityFill()`

#### 2e. Mode 4 — Simple Drag swap
New method `swapTilesAny(Tile source, Tile destination)`:
- No adjacency check (any two tiles can swap)
- Swap positions, increment `sessionMoves`, run `findMatchesInternal(activeTiles: [newT1, newT2])`
- If no matches: swap back, apply -1 penalty to `totalScore` (floored at 0) and `sessionUserScore`, set `lastMoveScore = -1`. Do NOT update `sessionOptimumScore` (it stays at 0 since optimum is not calculated in this mode).
- If matches: set `lastMoveScore` to the match score, add to `sessionUserScore`. Then call `processMatches()` which handles the `totalScore` update internally (same pattern as existing `swapTiles` — only `processMatches` adds to `totalScore`). Do NOT update `sessionOptimumScore`.
- Skip optimum calculation entirely (never call `calculateOptimumScore()`)
- Since `sessionOptimumScore` remains 0, `moveQuality` will be 0 — this is correct because RATIO is hidden in the UI for this mode.
- **Do NOT set `showOptimumCelebration = true`** — the existing check `moveScore >= optimumScore` would always be true when `optimumScore == 0`. Guard the celebration with `currentMode.calculatesOptimum == true` in addition to the score check. This same guard must apply in `endSnakeDrag()` for Mode 5.
- **Tap-to-select also works in Mode 4** but is limited to adjacent swaps only (uses existing `swapTiles`). This is intentional: tap = simple adjacent swap, drag = any-position swap. The two input methods serve different purposes.

#### 2f. Mode 5 — Snake Drag
New state fields:
- `List<Tile> snakeDragPath = []` — ordered list of tiles the dragged tile has visited
- `Tile? snakeDragOrigin` — the tile being dragged
- `List<Tile> snakeDragOriginalTiles = []` — snapshot of all tiles with their original positions at drag start (for reversal)

New methods:
- `startSnakeDrag(Tile tile)` — records origin, snapshots positions
- `updateSnakeDrag(Tile hoveredTile)` — if `hoveredTile` is already in path (backtrack), truncate path to that tile's index and restore all tiles beyond that point to their snapshotted original positions. Otherwise, extend path: `hoveredTile` shifts into the dragged tile's current logical position, and the dragged tile takes `hoveredTile`'s former position.

  **Concrete example:** Tiles A@(0,0), B@(0,1), C@(0,2), D@(0,3). User starts dragging A.
  - Path = [A]. A is being dragged (follows finger).
  - Finger moves over B → path = [A, B]. B shifts to (0,0) (A's original spot). A is now logically at (0,1).
  - Finger moves over C → path = [A, B, C]. C shifts to (0,1) (where A just was). A is now at (0,2).
  - Finger backtracks over B → path truncated to [A, B]. C is restored to (0,2). A is back at (0,1).
  - Finger backtracks to origin (0,0) → path = [A]. B restored to (0,1). A is back at (0,0). Full backtrack = no move.
- `endSnakeDrag()` — if final position == origin position (full backtrack), no move counted. Otherwise, run match detection on all tiles that moved. If no matches: restore all to `snakeDragOriginalTiles`, apply -1 penalty. If matches: process normally. Skip optimum.

#### 2g. Mode 6 — Arcade score drain
- Add `import 'dart:async';` to `game_state.dart` (not currently imported)
- Add `Timer? _arcadeTimer` field
- When mode is set to Arcade, start `Timer.periodic(Duration(seconds: 1), ...)` that decrements `totalScore` by 1 (floored at 0) and calls `notifyListeners()`
- Pause timer when `isPausedForSnapshot == true`; resume when snapshot continues
- Also pause timer while the refresh confirmation dialog is open (to be fair to the player). Add a `bool isDialogOpen = false` field to `GameState`. Set it to `true` before `showDialog()` and `false` after dialog is dismissed. The timer callback checks both `isPausedForSnapshot` and `isDialogOpen` — if either is true, skip the decrement.
- Cancel timer when switching away from Arcade mode or when `initializeBoard` is called for a different mode
- Timer does NOT run during mode selection dialog (session hasn't started until mode is selected)
- **Add `dispose()` override** to `GameState` that cancels `_arcadeTimer` and calls `super.dispose()`. This is required because `ChangeNotifier` has a `dispose()` method and the timer would otherwise leak.

### 3. Drag Interaction in BoardWidget (`lib/presentation/widgets/board_widget.dart`)

#### 3a. Adjacent drag (Modes 1, 2, 3, 6)
- Wrap each `TileWidget` with a `GestureDetector` adding `onPanStart`, `onPanUpdate`, `onPanEnd`
- `onPanStart`: record the tile and its starting position
- `onPanUpdate`: track finger position; if moved more than half a tile-size in a cardinal direction, identify the adjacent target tile
- `onPanEnd`: if a valid adjacent target was identified, call `swapTiles(source, target)`. If the tile is back at origin, do nothing.
- Visual feedback: the dragged tile follows the finger (offset from its grid position) during the drag

#### 3b. Any-position drag (Mode 4)
- Same pan gesture mechanics, but on `onPanEnd`, determine which grid cell the finger is over (using position math against the board layout)
- Call `swapTilesAny(source, destinationTile)` instead of `swapTiles`
- Tap-to-select also remains functional (existing `_handleTileTap` logic) — but limited to adjacent swaps only, exactly as current behavior

#### 3c. Snake drag (Mode 5)
- `onPanStart`: call `gameState.startSnakeDrag(tile)`
- `onPanUpdate`: determine which tile the finger is currently over. If it differs from the last tile in the path, call `gameState.updateSnakeDrag(hoveredTile)`. The board re-renders in real-time as tiles shift along the path.
- `onPanEnd`: call `gameState.endSnakeDrag()`
- The dragged tile renders at the finger position (elevated z-order) during drag
- No tap-to-select in this mode

#### 3d. Hit-testing helper
Add a method to `BoardWidget` state:
```dart
Tile? _tileAtPosition(Offset localPosition, double coinSize, double spacing, double padding)
```
Converts a local position within the board to the tile at that grid cell. Used by all drag handlers.

### 4. Mode Selection Dialog (`lib/presentation/widgets/mode_selection_dialog.dart`)

- New `StatelessWidget` displayed via `showDialog()`
- Layout: `Column` of `ListTile`-style buttons, each with:
  - Mode icon (left-aligned, all icons vertically aligned)
  - Mode name
  - Highlight or check mark on the currently active mode
- Close/cancel button (X icon in top-right or a "Cancel" button at bottom)
- On mode tap: call `gameState.setMode(selectedMode)`, then `Navigator.of(context).pop()`
- Styled consistently with existing `_showRefreshConfirmation` dialog (dark background, rounded corners, green accent)

### 5. Top Bar Updates (`lib/presentation/screens/game_screen.dart`)

#### 5a. Replace "MOVE CREDITS" with active mode
- In `_buildInfoColumn` call for the left circle: show the current mode's icon instead of the monetization icon
- Below the circle: show the mode name instead of "MOVE CREDITS"

#### 5b. Conditional optimum/ratio display
- When `currentMode.calculatesOptimum == false`:
  - Hide the OPTIMUM circle and label in the top bar
  - Hide the "RATIO: XX%" text in the stats line
  - Hide the "OPTIMUM:+N" text next to last move score
  - Hide the refresh button's `-N` penalty label (since there's no optimum to deduct)

#### 5c. Home button opens dialog
- In `_buildBottomBar()`, change the Home `IconButton.onPressed` from `() {}` to open `ModeSelectionDialog`

### 6. Documentation Updates

#### 6a. GAMEDIS.md
- Add a "## Game Modes" section after the existing scoring rules
- Document each mode's name, behavior, and key rules
- Note which modes calculate optimum and which don't
- Document drag mechanics for modes 4 and 5

#### 6b. README.md
- Update project description to mention multiple game modes
- Brief list of available modes

---

## Test Coverage

This section maps every new feature and changed behaviour to specific test cases. All tests use `flutter_test` (already a dev dependency). Existing test helpers (`makeTile`, `buildBoard`) in `test/game_state_test.dart` are reused and extended.

### `test/game_mode_test.dart` (new file)

**Purpose:** Verify `GameModeType` enum properties.

| Test case | Asserts |
|---|---|
| `convenient mode has correct properties` | `name == 'Convenient'`, `calculatesOptimum == true`, `usesGravity == false`, `allowsDragToAny == false`, `isSnakeDrag == false`, `hasScoreDrain == false`, `highScoreGeneration == false` |
| `highScores mode has correct properties` | `calculatesOptimum == true`, `highScoreGeneration == true`, all others false |
| `dropDown mode has correct properties` | `usesGravity == true`, `calculatesOptimum == true`, all others false |
| `simpleDrag mode has correct properties` | `allowsDragToAny == true`, `calculatesOptimum == false` |
| `snakeDrag mode has correct properties` | `allowsDragToAny == true`, `isSnakeDrag == true`, `calculatesOptimum == false` |
| `arcade mode has correct properties` | `hasScoreDrain == true`, `calculatesOptimum == true` |
| `all modes have non-empty name and valid icon` | Loop all enum values, verify `name.isNotEmpty` and `icon != null` |

**Mocks/doubles needed:** None.

---

### `test/game_state_test.dart` (extend existing file)

#### Group: `Mode switching`

| Test case | Asserts |
|---|---|
| `setMode resets session stats` | After playing some moves, call `setMode(highScores)`. Verify `sessionMoves == 0`, `sessionUserScore == 0`, `sessionOptimumScore == 0`, `totalScore == 0`, `lastMoveScore == 0` |
| `setMode reinitializes board with 20 tiles` | After `setMode`, verify `tiles.length == 20` and all tiles have valid row/col |
| `setMode preserves mode type` | `setMode(arcade)` → `currentMode == GameModeType.arcade` |
| `default mode is convenient` | Fresh `GameState()` → `currentMode == GameModeType.convenient` |

#### Group: `Conditional optimum calculation`

| Test case | Asserts |
|---|---|
| `optimum calculated in convenient mode` | Set board with known matches, verify `optimumScore > 0` |
| `optimum is zero in simpleDrag mode` | `setMode(simpleDrag)`, verify `optimumScore == 0`, `optimumMatchTiles.isEmpty`, `optimumSwapTiles.isEmpty` |
| `optimum is zero in snakeDrag mode` | Same as above for `snakeDrag` |
| `optimum calculated in arcade mode` | `setMode(arcade)`, set board with known matches, verify `optimumScore > 0` |

#### Group: `Mode 2 — High Scores constrained generation`

| Test case | Asserts |
|---|---|
| `initializeBoard in highScores mode attempts optimum >= 50` | Inject a seeded `Random` (add optional `Random` param to `GameState` constructor). Set mode to `highScores`, call `initializeBoard`. Since we can't guarantee ≥50 with random, verify that the method completes without error and board has 20 tiles. |
| `_generateTilesWithHighScoreConstraint falls back after max attempts` | Use a subclass or `@visibleForTesting` to expose attempt counting. Verify that after 40 total attempts (20 partial + 20 full), the last result is used. |

**Mocks/doubles needed:** Seeded `Random` injected into `GameState` constructor (add optional named parameter `Random? random`).

#### Group: `Mode 3 — Gravity fill`

New helper: `buildBoardWithGaps(List<Tile> overrides, Set<Point<int>> emptyPositions)` — creates a full 5x4 board using `buildBoard(overrides)`, then removes tiles at the specified positions, returning a `List<Tile>` shorter than 20. This simulates the state after matched tiles have been removed but before gravity fill runs. The `_applyGravityFill` method identifies empty positions by finding grid cells (row, col) with no tile. Note: requires adding `import 'dart:math';` to the test file (for `Point`).

| Test case | Asserts |
|---|---|
| `column drop: tiles fall down to fill gaps below` | Remove tile at (3,0), keep tile at (1,0). After gravity, tile from (1,0) should be at (3,0) if (2,0) is also empty, or at (2,0) if that was the gap. Verify by checking `tile.row` values. |
| `lateral fill: closest tile fills gap when no tile above` | Create a scenario where a column is empty but adjacent column has a tile nearby. Verify the lateral tile moves in. |
| `lateral fill: random tie-break when equidistant` | Create symmetric gaps. Run multiple times with different `Random` seeds. Verify both outcomes are possible (non-deterministic test: run 20 iterations, assert both left and right fills occurred at least once). |
| `all positions filled after gravity` | Remove several tiles, apply gravity, verify `tiles.length == 20` and all 20 grid positions are occupied. |
| `gravity not applied in convenient mode` | Remove tiles in Mode 1, verify in-place replacement (tiles keep same row/col as removed tiles). |

**Mocks/doubles needed:** Seeded `Random` for tie-break testing.

#### Group: `Mode 4 — swapTilesAny`

| Test case | Asserts |
|---|---|
| `non-adjacent swap with matches scores correctly` | Place matching tiles such that swapping (0,0) with (3,3) creates a match. Verify `totalScore` increases and `lastMoveScore > 0`. |
| `non-adjacent swap without matches reverts and applies penalty` | Swap two tiles that create no match. Verify tiles return to original positions, `totalScore` decreased by 1 (or stays 0), `lastMoveScore == -1`. |
| `swapTilesAny does not calculate optimum` | After a successful swap in simpleDrag mode, verify `optimumScore == 0`. |
| `swapTilesAny blocked during isMatching` | Set `isMatching = true`, call `swapTilesAny`. Verify no state changes. |
| `swapTilesAny blocked during isPausedForSnapshot` | Set `isPausedForSnapshot = true`, call `swapTilesAny`. Verify no state changes. |

#### Group: `Mode 5 — Snake drag`

| Test case | Asserts |
|---|---|
| `startSnakeDrag initializes path and snapshots` | Call `startSnakeDrag(tile)`. Verify `snakeDragPath == [tile]`, `snakeDragOrigin == tile`, `snakeDragOriginalTiles` contains all 20 tiles with original positions. |
| `updateSnakeDrag extends path and shifts tile` | Start drag at (0,0), update with tile at (0,1). Verify tile at (0,1) moved to (0,0)'s original position, dragged tile is now at (0,1). Path length == 2. |
| `updateSnakeDrag backtrack restores positions` | Extend path through 3 tiles, then update with the 2nd tile (backtrack). Verify 3rd tile restored to original position, path length == 2. |
| `full backtrack means no move counted` | Start drag, extend path, backtrack fully to origin. Call `endSnakeDrag()`. Verify `sessionMoves` unchanged, no penalty, all tiles at original positions. |
| `endSnakeDrag with matches processes correctly` | Arrange board so snake drag creates a match. Verify `totalScore` increases, matched tiles removed and refilled. |
| `endSnakeDrag without matches reverts and applies penalty` | End drag with no matches. Verify all tiles restored, `lastMoveScore == -1`, `totalScore` decreased by 1. |
| `endSnakeDrag does not calculate optimum` | After snake drag in snakeDrag mode, verify `optimumScore == 0`. |

#### Group: `Mode 6 — Arcade score drain`

Uses `fakeAsync` from `flutter_test` for deterministic timer control. **Important:** `GameState` instantiation and `setMode(arcade)` must both occur within the `fakeAsync` callback so that `Timer.periodic` is captured by the fake clock.

| Test case | Asserts |
|---|---|
| `score decreases by 1 per second in arcade mode` | `fakeAsync`: set mode to arcade, then set `totalScore = 10`, advance by 3 seconds. Verify `totalScore == 7`. (Must set `totalScore` after `setMode` since `setMode` resets it to 0.) |
| `score floors at 0` | `fakeAsync`: set mode to arcade, set `totalScore = 2`, advance 5 seconds. Verify `totalScore == 0`. |
| `score drain pauses during snapshot` | `fakeAsync`: set `isPausedForSnapshot = true`, advance 3 seconds. Verify `totalScore` unchanged. |
| `score drain resumes after snapshot continues` | `fakeAsync`: pause, advance 2s, unpause, advance 2s. Verify only 2 points drained (not 4). |
| `switching away from arcade cancels timer` | `fakeAsync`: set arcade, advance 2s, switch to convenient, advance 5s. Verify score decreased only by 2. |
| `timer not running in non-arcade modes` | `fakeAsync`: set convenient mode, set `totalScore = 10`, advance 10s. Verify `totalScore == 10`. |

**Mocks/doubles needed:** `fakeAsync` wrapper for all timer tests.

---

### `test/mode_selection_dialog_test.dart` (new file — widget test)

| Test case | Asserts |
|---|---|
| `dialog displays all 6 modes` | Pump `ModeSelectionDialog`, find 6 mode name texts. |
| `dialog highlights current mode` | Create with `currentMode: convenient`, verify Convenient row has highlight styling. |
| `tapping a mode calls setMode and dismisses` | Tap "High Scores" row, verify `gameState.currentMode == highScores` and dialog is dismissed. |
| `cancel button dismisses without changing mode` | Tap cancel, verify mode unchanged and dialog dismissed. |
| `icons are vertically aligned` | Verify all Icon widgets share the same x-offset (left alignment). |

**Mocks/doubles needed:** `GameState` instance passed to the dialog. No mocking needed since `GameState` is a concrete `ChangeNotifier`.

---

### `test/game_screen_test.dart` (new file — widget test)

| Test case | Asserts |
|---|---|
| `top bar shows mode name and icon for convenient` | Pump `GameScreen`, find text "Convenient" and `Icons.spa`. |
| `top bar hides OPTIMUM and RATIO in simpleDrag mode` | Set mode to `simpleDrag`, pump. Verify OPTIMUM and RATIO text widgets are absent. |
| `top bar shows OPTIMUM and RATIO in convenient mode` | Verify both are present. |
| `home button opens mode selection dialog` | Tap home icon, verify dialog appears. |
| `refresh dialog hides penalty in non-optimum modes` | Set mode to `simpleDrag`, tap refresh. Verify penalty text is not shown. |

**Mocks/doubles needed:** None (uses real `GameState`).

---

### Test file structure summary

```
test/
  game_mode_test.dart          (new — enum property tests)
  game_state_test.dart         (extend — mode switching, optimum, modes 2-6 logic)
  mode_selection_dialog_test.dart  (new — widget tests for dialog)
  game_screen_test.dart        (new — widget tests for top bar / conditional UI)
```

**Note on package imports:** The `pubspec.yaml` declares `name: smatcher` and the Dart package resolver registers the package as `smatcher`. The existing test file (`test/game_state_test.dart`) uses `package:badger/...` imports, which is **incorrect** and causes test failures. All new test files must use `package:smatcher/...` imports. As a prerequisite, the existing test file's imports should also be fixed to use `package:smatcher/...`.

---

## Task List

### Task 0 – Fix Existing Test Imports

**Description:** The existing `test/game_state_test.dart` uses `package:badger/...` imports, but the package is named `smatcher` in `pubspec.yaml`. Fix the imports to use `package:smatcher/domain/logic/game_state.dart` and `package:smatcher/domain/models/tile.dart`. Verify the existing tests pass after the fix.

**Files:** `test/game_state_test.dart`

**Dependencies:** None

**Complexity:** S

**Verification steps:**
- [ ] `flutter test test/game_state_test.dart` passes all existing tests
- [ ] `flutter analyze` passes
- [ ] No other changes needed

**Status:** `not started`

---

### Task 1 – Game Mode Enum and Model

**Description:** Create `lib/domain/models/game_mode.dart` with the `GameModeType` enum and an extension (or companion class) providing properties for each mode: `name`, `icon`, `calculatesOptimum`, `usesGravity`, `allowsDragToAny`, `isSnakeDrag`, `hasScoreDrain`, `highScoreGeneration`. Import `flutter/material.dart` for `IconData` and `Icons`.

**Files:** `lib/domain/models/game_mode.dart` (new)

**Dependencies:** None

**Complexity:** S

**Verification steps:**
- [ ] `flutter analyze` passes with no errors or warnings introduced by this task
- [ ] `flutter build apk --debug` compiles without errors
- [ ] Unit test verifies each enum value returns correct property values
- [ ] No regressions in adjacent features (app still launches, existing game works)
- [ ] Unit test added: `test/game_mode_test.dart`

**Status:** `not started`

---

### Task 2 – Integrate Mode into GameState (Core Wiring)

**Description:** Add `GameModeType currentMode` field (default: `convenient`) and `setMode(GameModeType)` method to `GameState`. `setMode` updates `currentMode`, resets `totalScore = 0`, then calls `initializeBoard(resetSession: true)`. Note: `initializeBoard` does NOT reset `totalScore` itself, so `setMode` must do it explicitly. Make `calculateOptimumScore()` skip computation (set `optimumScore = 0`, clear `optimumMatchTiles`/`optimumSwapTiles`) when `currentMode.calculatesOptimum == false`. Also guard the optimum celebration check (`showOptimumCelebration = true`) in the existing `swapTiles` method with `currentMode.calculatesOptimum == true`, since `swapTiles` is still callable in modes where optimum is not tracked (e.g., Mode 4 via tap-to-select). Import the new game mode model.

**Files:** `lib/domain/logic/game_state.dart`

**Dependencies:** Task 1

**Complexity:** S

**Verification steps:**
- [ ] `flutter analyze` passes with no errors or warnings introduced by this task
- [ ] `flutter build apk --debug` compiles without errors
- [ ] Manual test: app launches in Convenient mode, existing gameplay unchanged
- [ ] Unit test: `setMode` resets session stats and reinitializes board
- [ ] Unit test: optimum is 0 when mode doesn't calculate it
- [ ] No regressions: existing `game_state_test.dart` tests still pass

**Status:** `not started`

---

### Task 3 – Mode Selection Dialog

**Description:** Create `lib/presentation/widgets/mode_selection_dialog.dart`. A dialog widget showing all 6 modes as rows: icon (vertically aligned) + mode name. The currently active mode is visually highlighted (e.g., green border or check icon). A close button dismisses without changing mode. On mode tap: call `gameState.setMode(selected)` and dismiss. Style consistently with the existing refresh confirmation dialog (`Color(0xFF2D2D2D)` background, `BorderRadius.circular(24)`, white text, green accent for active/confirm elements).

**Files:** `lib/presentation/widgets/mode_selection_dialog.dart` (new)

**Dependencies:** Task 1, Task 2

**Complexity:** M

**Verification steps:**
- [ ] `flutter analyze` passes with no errors or warnings introduced by this task
- [ ] `flutter build apk --debug` compiles without errors
- [ ] Manual test: dialog opens, shows all 6 modes with icons vertically aligned
- [ ] Manual test: tapping a mode selects it, dismisses dialog, resets session stats
- [ ] Manual test: cancel button dismisses without changing mode or resetting stats
- [ ] Manual test: currently active mode is visually distinct
- [ ] No regressions in adjacent features (game screen still renders correctly)

**Status:** `not started`

---

### Task 4 – Top Bar & Home Button Updates

**Description:** In `game_screen.dart`:
1. Change the Home icon's `onPressed` to show the `ModeSelectionDialog`.
2. Replace the left info column ("MOVE CREDITS" + monetization icon) with the current mode's icon and name.
3. Conditionally hide OPTIMUM circle/label, RATIO stat, and optimum-related text next to last-move score when `currentMode.calculatesOptimum == false`.
4. Conditionally hide the `-N` penalty label on the refresh button when optimum is not calculated.

**Files:** `lib/presentation/screens/game_screen.dart`

**Dependencies:** Task 2, Task 3

**Complexity:** M

**Verification steps:**
- [ ] `flutter analyze` passes with no errors or warnings introduced by this task
- [ ] `flutter build apk --debug` compiles without errors
- [ ] Manual test: top bar shows current mode icon and name where "MOVE CREDITS" was
- [ ] Manual test: Home icon opens mode selection dialog
- [ ] Manual test: in modes 1/2/3/6, OPTIMUM and RATIO are visible
- [ ] Manual test: in modes 4/5, OPTIMUM circle, RATIO, and optimum text are all hidden
- [ ] Manual test: refresh penalty label hidden in modes 4/5
- [ ] No regressions: score display, celebration overlay, snapshot mode still work

**Status:** `not started`

---

### Task 5 – Mode 2: High Scores Tile Generation

**Description:** In `GameState`, add constrained tile generation for Mode 2:
1. New method `_generateTilesWithHighScoreConstraint(List<Point<int>> positions)`: generates tiles for the given positions, places them on the board, runs `calculateOptimumScore()`, checks if `optimumScore >= 50`. Retries up to 20 times (re-generating only the new tiles each attempt).
2. If 20 attempts fail: regenerate the entire board up to 20 times with the same check.
3. If still fails: accept the last result.
4. Hook into `processMatches()` — when in Mode 2, use this method instead of plain `_generateRandomTile` for refill.
5. Hook into `initializeBoard()` — when in Mode 2, after initial generation, apply the same constraint logic (up to 20 board retries for optimum ≥ 50).

**Files:** `lib/domain/logic/game_state.dart`

**Dependencies:** Task 2

**Complexity:** M

**Verification steps:**
- [ ] `flutter analyze` passes with no errors or warnings introduced by this task
- [ ] `flutter build apk --debug` compiles without errors
- [ ] Unit test: with a mocked/seeded random, verify that generation retries when optimum < 50
- [ ] Unit test: verify fallback to last result after 20+20 attempts
- [ ] Manual test: in Mode 2, observe that optimum score tends to be ≥ 50 after each move
- [ ] No regressions: Mode 1 tile generation unchanged; existing tests pass

**Status:** `not started`

---

### Task 6 – Mode 3: Drop Down Gravity Fill

**Description:** In `GameState`, add gravity-based fill for Mode 3:
1. New method `_applyGravityFill(Set<String> removedTileIds)`:
   a. Record empty positions from removed tiles
   b. **Column drop**: for each column, bottom-to-top, pull the nearest tile above each empty cell downward
   c. **Lateral fill**: for remaining empty cells, find the closest filled tile by Manhattan distance. On tie, randomly choose. Move that tile into the gap. Repeat until no more lateral moves are possible.
   d. **Generate new tiles**: fill any remaining empty positions with new random tiles (these will typically be at the top/edges)
2. In `processMatches()`, branch on `currentMode.usesGravity`: if true, call `_applyGravityFill()` instead of the current in-place refill.
3. No chain-matching after fill.

**Files:** `lib/domain/logic/game_state.dart`

**Dependencies:** Task 2

**Complexity:** L

**Verification steps:**
- [ ] `flutter analyze` passes with no errors or warnings introduced by this task
- [ ] `flutter build apk --debug` compiles without errors
- [ ] Unit test: given a board with specific tiles removed, verify tiles fall down within columns
- [ ] Unit test: verify lateral fill picks closest tile, and random tie-break occurs
- [ ] Unit test: verify all 20 positions are filled after gravity + generation
- [ ] Manual test: in Mode 3, tiles visibly fall down and shift laterally after matches
- [ ] No regressions: Mode 1 refill behavior unchanged

**Status:** `not started`

---

### Task 7 – Drag Infrastructure in BoardWidget

**Description:** Add drag gesture handling to `BoardWidget`:
1. Add `_tileAtPosition(Offset localPosition, double coinSize, double spacing, double padding)` helper that converts a local offset to the `Tile` at that grid position (or null).
2. Add state fields: `Tile? _draggedTile`, `Offset? _dragOffset`, `Tile? _dragTarget`. When a drag starts (`onPanStart`), clear `_selectedTile` to avoid conflicts between tap-to-select and drag interactions.
3. **Important:** `TileWidget` already contains a `GestureDetector` for `onTap`. To avoid gesture arena conflicts, remove the `GestureDetector` from `TileWidget` and move all gesture handling (tap + pan) to `BoardWidget`. Use a single `GestureDetector` per tile in `BoardWidget` that handles both `onTap` (delegating to `_handleTileTap`) and `onPanStart`/`onPanUpdate`/`onPanEnd`. `TileWidget` becomes a pure visual widget (remove its `onTap` parameter and internal `GestureDetector`).
4. During drag, the dragged tile renders at the finger position (elevated in the Stack's z-order via sort order).
5. For **modes 1, 2, 3, 6** (adjacent-only drag):
   - `onPanEnd`: if finger is over an adjacent tile, call `gameState.swapTiles(source, target)`. If back at origin, do nothing.
6. For **mode 4** (any-position drag):
   - `onPanEnd`: determine destination tile from finger position, call `gameState.swapTilesAny(source, destination)`. If back at origin, do nothing.
   - Tap-to-select remains functional for adjacent swaps only (existing `_handleTileTap`).
7. Disable tap-to-select in Mode 5 (snake drag handled in Task 9): add an early return in `_handleTileTap` when `widget.gameState.currentMode.isSnakeDrag == true`.

**Files:** `lib/presentation/widgets/board_widget.dart`, `lib/presentation/widgets/tile_widget.dart` (refactor: remove `GestureDetector` and `onTap` parameter)

**Dependencies:** Task 2

**Complexity:** L

**Verification steps:**
- [ ] `flutter analyze` passes with no errors or warnings introduced by this task
- [ ] `flutter build apk --debug` compiles without errors
- [ ] Manual test: in Mode 1, drag a tile to an adjacent cell — swap occurs
- [ ] Manual test: in Mode 1, drag and return to origin — no move counted
- [ ] Manual test: in Mode 1, tap-to-select still works alongside drag
- [ ] Manual test: in Mode 4, drag a tile to a distant cell — swap occurs
- [ ] Manual test: in Mode 4, tap-to-select works for adjacent tiles only
- [ ] No regressions: existing tap interaction unaffected in modes 1/2/3/6

**Status:** `not started`

---

### Task 8 – Mode 4: Simple Drag Any-Position Swap Logic

**Description:** In `GameState`, add `swapTilesAny(Tile t1, Tile t2)`:
1. No adjacency check — any two tiles can swap.
2. Swap positions, increment `sessionMoves`.
3. Run `findMatchesInternal(activeTiles: [newT1, newT2])`.
4. If no matches: swap back, apply -1 penalty to `totalScore` (floored at 0) and `sessionUserScore`, set `lastMoveScore = -1`.
5. If matches: set `lastMoveScore` to the match score, add to `sessionUserScore`. Then call `processMatches()` which handles the `totalScore` update (do NOT update `totalScore` directly — same pattern as existing `swapTiles`).
6. Do NOT call `calculateOptimumScore()` at any point.
7. Handle `isMatching` and `isPausedForSnapshot` guards same as current `swapTiles`.

**Files:** `lib/domain/logic/game_state.dart`

**Dependencies:** Task 2

**Complexity:** M

**Verification steps:**
- [ ] `flutter analyze` passes with no errors or warnings introduced by this task
- [ ] `flutter build apk --debug` compiles without errors
- [ ] Unit test: non-adjacent swap that produces matches scores correctly
- [ ] Unit test: non-adjacent swap with no matches reverts and applies penalty
- [ ] Unit test: optimum is not calculated after swap
- [ ] Manual test: in Mode 4, drag a tile to a far cell — correct behavior
- [ ] No regressions: `swapTiles` (adjacent) still works correctly for other modes

**Status:** `not started`

---

### Task 9 – Mode 5: Snake Drag Logic and UI

**Description:**

**GameState changes** (`lib/domain/logic/game_state.dart`):
1. Add fields: `List<Tile> snakeDragPath`, `Tile? snakeDragOrigin`, `List<Tile> snakeDragOriginalTiles` (snapshot of all tiles with original positions at drag start).
2. `startSnakeDrag(Tile tile)`: set origin, snapshot all tile positions, init path with `[tile]`.
3. `updateSnakeDrag(Tile hoveredTile)`:
   - If `hoveredTile` is already in the path (backtrack): truncate path to that tile's index, restore all tiles after that point to their snapshotted positions.
   - Otherwise (extend): add `hoveredTile` to path. `hoveredTile` shifts into the dragged tile's current logical position, and the dragged tile takes `hoveredTile`'s former position (see concrete example in section 2f). Call `notifyListeners()` for real-time animation.
4. `endSnakeDrag()`:
   - If all tiles are back at original positions (full backtrack): no move counted, clear drag state.
   - Otherwise: increment `sessionMoves`, run `findMatchesInternal` with all tiles that moved as `activeTiles`.
   - If no matches: restore all tiles to `snakeDragOriginalTiles`, apply -1 penalty.
   - If matches: process via `processMatches()`. Do NOT set `showOptimumCelebration = true` — guard with `currentMode.calculatesOptimum == true` (same guard as in `swapTiles` and `swapTilesAny`).
   - Do NOT calculate optimum.
   - Clear all snake drag state.

**BoardWidget changes** (`lib/presentation/widgets/board_widget.dart`):
1. In Mode 5, `onPanStart` calls `gameState.startSnakeDrag(tile)`.
2. `onPanUpdate`: determine hovered tile via `_tileAtPosition()`. If different from last path entry, call `gameState.updateSnakeDrag(hoveredTile)`.
3. `onPanEnd`: call `gameState.endSnakeDrag()`.
4. The dragged tile renders at finger position with elevated z-order.
5. Disable tap-to-select in Mode 5.

**Files:** `lib/domain/logic/game_state.dart`, `lib/presentation/widgets/board_widget.dart`

**Dependencies:** Task 2, Task 7

**Complexity:** L

**Verification steps:**
- [ ] `flutter analyze` passes with no errors or warnings introduced by this task
- [ ] `flutter build apk --debug` compiles without errors
- [ ] Unit test: snake path extension shifts tiles correctly
- [ ] Unit test: backtracking restores tiles to original positions
- [ ] Unit test: full backtrack = no move counted
- [ ] Unit test: no matches after snake drag = penalty + full restore
- [ ] Manual test: in Mode 5, drag across multiple tiles — see them shift in real-time
- [ ] Manual test: backtrack during drag — tiles animate back
- [ ] Manual test: release with no matches — all tiles return, penalty applied
- [ ] No regressions: other modes' drag/tap interactions unaffected

**Status:** `not started`

---

### Task 10 – Mode 6: Arcade Score Drain

**Description:** In `GameState`:
1. Add `Timer? _arcadeTimer` field and `bool isDialogOpen = false` field.
2. When `setMode(GameModeType.arcade)` is called (or board initializes in Arcade mode): start `Timer.periodic(Duration(seconds: 1), (_) { ... })` that decrements `totalScore` by 1 (floored at 0) and calls `notifyListeners()`.
3. The timer callback checks `isPausedForSnapshot` and `isDialogOpen` — if either is true, skip the decrement. This means the timer keeps ticking but has no effect during pauses. Modify `continueFromSnapshot()` to call `notifyListeners()` (it already does) so the UI updates after snapshot resume — no additional timer management needed.
4. Cancel `_arcadeTimer` in `setMode()` when switching to any non-Arcade mode.
5. Cancel in `initializeBoard()` if not in Arcade mode.
6. Ensure the timer is properly cancelled if `GameState` is disposed (add a `dispose()` method or document that `GameState` currently has no disposal — the app has a single screen).

In `game_screen.dart`:
7. In `_showRefreshConfirmation()`, set `_gameState.isDialogOpen = true` before calling `showDialog()` and set `_gameState.isDialogOpen = false` after the dialog is dismissed (in the `.then()` callback or after `await`).

**Files:** `lib/domain/logic/game_state.dart`, `lib/presentation/screens/game_screen.dart`

**Dependencies:** Task 2

**Complexity:** S

**Verification steps:**
- [ ] `flutter analyze` passes with no errors or warnings introduced by this task
- [ ] `flutter build apk --debug` compiles without errors
- [ ] Manual test: in Mode 6, score visibly decreases every second
- [ ] Manual test: score stops at 0, does not go negative
- [ ] Manual test: during snapshot pause, score does not decrease
- [ ] Manual test: switching to another mode stops the drain
- [ ] No regressions: no timer running in other modes

**Status:** `not started`

---

### Task 11 – Board Redraw Penalty Adjustment for Non-Optimum Modes

**Description:** In `GameState.initializeBoard()` and `_showRefreshConfirmation()` in `game_screen.dart`:
1. When `currentMode.calculatesOptimum == false`, board redraw should NOT deduct optimum score (since it's 0/not tracked). The `deductScore` parameter still works, but the deduction will naturally be 0 since `optimumScore == 0`.
2. Verify that the refresh confirmation dialog text and penalty display make sense for non-optimum modes. If optimum is 0, either hide the penalty info or show "-0" (preferred: hide the penalty section entirely and simplify the dialog text to "A new board will be generated.").

**Files:** `lib/presentation/screens/game_screen.dart` (code changes only here; `game_state.dart` needs no changes since `optimumScore == 0` naturally handles the deduction)

**Dependencies:** Task 2, Task 4

**Complexity:** S

**Verification steps:**
- [ ] `flutter analyze` passes with no errors or warnings introduced by this task
- [ ] `flutter build apk --debug` compiles without errors
- [ ] Manual test: in Mode 4/5, redraw dialog doesn't show penalty amount, simplified text shown
- [ ] Manual test: in Mode 1/2/3/6, redraw dialog still shows penalty correctly
- [ ] No regressions: redraw functionality works in all modes

**Status:** `not started`

---

### Task 12 – Documentation Updates

**Description:**
1. **GAMEDIS.md**: Add a `## Game Modes` section after the scoring rules. Document each mode (name, behavior, key rules). Note which modes calculate optimum. Document drag mechanics for modes 4/5. Document Arcade score drain.
2. **README.md**: Update project description to mention SMatcher has 6 game modes. Add a brief bulleted list of mode names.

**Files:** `GAMEDIS.md`, `README.md`

**Dependencies:** All previous tasks (document final behavior)

**Complexity:** S

**Verification steps:**
- [ ] GAMEDIS.md accurately describes all 6 modes and their rules
- [ ] README.md mentions the game modes
- [ ] No formatting issues in markdown
- [ ] No contradictions with implemented behavior

**Status:** `not started`

---

### Task 13 – Unit Tests for All New Mode Logic

**Description:** Add/update tests in `test/`:
1. `test/game_mode_test.dart`: verify enum properties for all 6 modes.
2. `test/game_state_test.dart` (extend existing):
   - Mode switching resets session stats and `totalScore`
   - Mode 2: constrained generation retries (mock random if needed)
   - Mode 3: gravity fill — column drop + lateral fill + random tie-break
   - Mode 4: `swapTilesAny` with matches and without
   - Mode 5: snake drag path extension, backtrack, full backtrack, match/no-match outcomes
   - Mode 6: score drain ticks (use `fakeAsync` from `flutter_test`)
   - Optimum skipped for modes 4/5
   - Redraw penalty behavior in non-optimum modes (Task 11 coverage)

**Files:** `test/game_mode_test.dart` (new), `test/game_state_test.dart` (extend)

**Dependencies:** Tasks 1–11

**Complexity:** L

**Verification steps:**
- [ ] `flutter test` passes all new and existing tests
- [ ] `flutter analyze` passes
- [ ] Tests cover the key logic branches documented above
- [ ] No flaky tests (random tie-break tests use seeded random or verify either valid outcome)

**Status:** `not started`

---

### Task 14 – Widget Tests for Dialog and Screen

**Description:** Add widget tests in `test/`:
1. `test/mode_selection_dialog_test.dart` (new): test dialog display, mode selection, cancel, and visual highlighting of active mode. Wrap widgets in `MaterialApp` for proper test context.
2. `test/game_screen_test.dart` (new): test top bar conditional display (mode name/icon shown, OPTIMUM/RATIO hidden in modes 4/5), home button opens dialog, refresh dialog hides penalty in non-optimum modes.

**Files:** `test/mode_selection_dialog_test.dart` (new), `test/game_screen_test.dart` (new)

**Dependencies:** Tasks 3, 4, 11

**Complexity:** M

**Verification steps:**
- [ ] `flutter test` passes all new and existing tests
- [ ] `flutter analyze` passes
- [ ] Widget tests cover all cases from the Test Coverage section
- [ ] Tests use `MaterialApp` wrapper for proper widget context

**Status:** `not started`

---

## Known Pre-Existing Issues

**Celebration overlay shows wrong score:** The `_buildCelebrationOverlay` in `game_screen.dart` displays `_gameState.optimumScore`, but by the time the overlay renders, `processMatches` has already called `calculateOptimumScore()` for the new board state — so the displayed score is the *next* board's optimum, not the move that triggered the celebration. This plan adds a `calculatesOptimum` guard to the celebration but does not fix the display bug. A separate fix could save `previousOptimumScore` before recalculation and display that instead.

## Task Dependency Graph

```
Task 0 (Fix test imports — prerequisite)
Task 1 (GameMode enum)
  └── Task 2 (GameState core wiring)
        ├── Task 3 (Mode selection dialog)
        │     └── Task 4 (Top bar & home button)
        │           └── Task 11 (Redraw penalty adjustment)
        ├── Task 5 (Mode 2: High Scores gen)
        ├── Task 6 (Mode 3: Drop Down gravity)
        ├── Task 7 (Drag infrastructure + TileWidget refactor)
        │     └── Task 9 (Mode 5: Snake drag)
        ├── Task 8 (Mode 4: Simple Drag logic)
        └── Task 10 (Mode 6: Arcade drain)

After all of Tasks 1–11 complete:
  ├── Task 13 (Unit tests)
  ├── Task 14 (Widget tests)
  └── Task 12 (Documentation — last)
```

**Parallelizable groups** (after Task 2 is complete):
- Group A: Tasks 5, 6, 8, 10 (independent mode logic)
- Group B: Task 3 → Task 4 → Task 11 (UI chain)
- Group C: Task 7 → Task 9 (drag chain)
- After all logic/UI tasks: Tasks 13, 14 can run in parallel
- Task 12 last (documentation reflects final implementation)
