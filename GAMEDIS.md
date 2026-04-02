# Game design document

The game is a Organizing Puzzle game with the following features:

Game field is 4x5 grid. Filled with tiles, having 3 attributes:
1. Color (5 colors)
2. Letter (A-Z)
3. Badge (1-9)

## Groups matching

User initiates matching group finding process by swapping two adjacent tiles.
If the swap results in a match of 3 or more tiles, the tiles are removed and the score is updated. The matching is parformed by all 3 attributes. Matching group should include not less than 3 tiles. Matching tiles can be located horizontally, vertically or diagonally. Matching tiles group should include one of the tiles being swapped by user and having at least one of the attributes same as the other tiles in the group. Depending on the number of similar attributes in the matching group the score of the match is calculated.

## Score calculation rules

The score is based on the value of the badge of each tile in the group.

Each attribute match provides a multiplier for the sum of badge values in the group:
1. **Color Match:** Multiplier 1x.
2. **Badge (Value) Match:** Multiplier 2x.
3. **Letter Match:** Multiplier 3x.

Total score of the group is the sum of the scores for each matching attribute.
If a group matches multiple attributes, their multipliers are summed.
Example: A group matching both Letter (3x) and Badge (2x) has a total multiplier of 5x.

Total score of the move is the sum of the scores of all groups found in the move.

Example:

In the matrix below tiles are represented in a form: 0A2!, where 0 is color index (0-4), A is letter (A-Z), 2 is badge value (1-9). With "!" tiles, swapped by user, are marked.

Before move:

0C2  2C2! 0A4  1X5
1B1  0A3! 3D3  4E4
0F5  1G2  2C2  3I8
4J9  0K2  1L2  2M3
3N4  4O5  0P6  1Q7

After move:

0C2  0A3! 0A4  1X5
1B1  2C2! 3D3  4E4
0F5  1G2  2C2  3I8
4J9  0K2  1L2  2M3
3N4  4O5  0P6  1Q7

1. Identify Intersecting Tiles
The player swapped tiles at (0, 1) and (1, 1). In the After move state:
- Tile 1 (flipped): 0A3 at Row 0, Col 1.
- Tile 2 (flipped): 2C2 at Row 1, Col 1.

2. Identify Matching Groups (Intersecting with Flipped Tiles)

Group A: Horizontal (Row 0)
- Tiles: (0,0), (0,1), (0,2) -> 0C2, 0A3, 0A4
- Shared Attributes: Color (0)
- Multiplier: 1x (Color)
- Calculation: (2 + 3 + 4) x 1 = 9 points

Group B: Vertical (Col 1)
- Tiles: (1,1), (2,1), (3,1) -> 2C2, 1G2, 0K2
- Shared Attributes: Badge (2)
- Multiplier: 2x (Badge)
- Calculation: (2 + 2 + 2) x 2 = 12 points

Group C: Diagonal (\ Direction)
- Tiles: (0,0), (1,1), (2,2) -> 0C2, 2C2, 2C2
- Shared Attributes: Letter (C) AND Badge (2)
- Multiplier: 3x (Letter) + 2x (Badge) = 5x
- Calculation: (2 + 2 + 2) x 5 = 30 points

---

3. Total Move Score
- Group A: 9
- Group B: 12
- Group C: 30
- Total: 51 points

Summary for User Review:
- Matching Groups: 3
- Highest Multiplier: 5x (Diagonal match sharing both Letter 'C' and Value 2)
- Total Move Score: 51

## Game Modes

SMatcher offers six distinct game modes, each varying tile mechanics, input methods, and scoring rules. The active mode is displayed in the top bar and can be changed via the Home button, which opens the mode selection dialog. Switching modes resets all session statistics.

### Mode 1: Convenient (default)

- **Icon:** Spa
- **Input:** Tap-to-select adjacent swap, or drag to adjacent tile
- **Tile generation:** Standard random generation
- **Refill:** In-place replacement (new tiles appear at the same positions as removed tiles)
- **Optimum:** Calculated. OPTIMUM and RATIO are displayed in the top bar.
- **Special rules:** None. This is the standard gameplay mode.

### Mode 2: High Scores

- **Icon:** Trophy (emoji_events)
- **Input:** Tap-to-select adjacent swap, or drag to adjacent tile
- **Tile generation:** Constrained generation ensuring the optimum score is at least 50. After removing matched tiles, new tiles are generated and the optimum is recalculated. If the optimum is below 50, tiles are regenerated (up to 20 partial attempts, then up to 20 full-board attempts). Falls back to last result if all attempts fail.
- **Refill:** In-place replacement
- **Optimum:** Calculated (and guaranteed to be high). OPTIMUM and RATIO are displayed.
- **Special rules:** Higher optimum scores lead to more challenging and rewarding gameplay.

### Mode 3: Drop Down

- **Icon:** Arrow downward
- **Input:** Tap-to-select adjacent swap, or drag to adjacent tile
- **Tile generation:** Standard random generation for new tiles
- **Refill:** Gravity-based fill:
  1. **Column drop:** Tiles above empty cells fall downward within their column.
  2. **Lateral fill:** Remaining empty cells are filled by the closest tile (by Manhattan distance). Ties are broken randomly.
  3. **New tiles:** Any remaining empty positions (typically at the top or edges) are filled with new random tiles.
  4. No chain-matching occurs after the fill; the game waits for the next user move.
- **Optimum:** Calculated. OPTIMUM and RATIO are displayed.
- **Special rules:** Gravity creates a more dynamic board after each match.

### Mode 4: Simple Drag

- **Icon:** Swipe
- **Input:** Drag any tile to any other tile's position (no adjacency requirement). Tap-to-select is also available but limited to adjacent swaps only.
- **Tile generation:** Standard random generation
- **Refill:** In-place replacement
- **Optimum:** Not calculated. OPTIMUM circle, RATIO, and optimum-related text are hidden from the top bar. The refresh button penalty label is also hidden.
- **Special rules:**
  - Any two tiles on the board can be swapped via drag.
  - If a non-adjacent swap produces no matches, tiles revert and a -1 penalty is applied to the total score (floored at 0).
  - If a swap produces matches, scoring proceeds normally.

### Mode 5: Snake Drag

- **Icon:** Gesture
- **Input:** Drag-only with a snake path. No tap-to-select.
  1. Start dragging a tile; it follows the finger.
  2. As the dragged tile passes over other tiles, those tiles shift into the dragged tile's previous position, creating a "snake" trail.
  3. Backtracking along the path restores tiles to their original positions.
  4. On release: if the tile is back at its starting position (full backtrack), no move is counted. Otherwise, match detection runs on all tiles that moved.
- **Tile generation:** Standard random generation
- **Refill:** In-place replacement
- **Optimum:** Not calculated. OPTIMUM circle, RATIO, and optimum-related text are hidden. The refresh button penalty label is also hidden.
- **Special rules:**
  - If no matches are found after ending the drag, all tiles return to their original positions and a -1 penalty is applied.
  - The snake drag provides a unique multi-tile rearrangement mechanic.

### Mode 6: Arcade

- **Icon:** Timer
- **Input:** Tap-to-select adjacent swap, or drag to adjacent tile
- **Tile generation:** Standard random generation
- **Refill:** In-place replacement
- **Optimum:** Calculated. OPTIMUM and RATIO are displayed.
- **Special rules:**
  - **Score drain:** The total score decreases by 1 every second (floored at 0).
  - The drain pauses during snapshot mode and while the refresh confirmation dialog is open.
  - Switching away from Arcade mode stops the drain timer.
  - The timer does not run during the mode selection dialog.
  - This mode adds time pressure, encouraging fast play.
