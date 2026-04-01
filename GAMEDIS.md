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

1. if all tiles in the group have identical color, the score is the sum of the badge values of all tiles in the group.
2. if all tiles in the group have identical badge value, the score is the sum of the badge values of all tiles in the group multiplied by 2.
3. if all tiles in the group have identical letter, the score is the sum of the badge values of all tiles in the group multiplied by 3.

Total score of the group is the sum of the scores for each attribute.
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
- Intersecting: Yes (contains 0A3 at 0,1)
- Shared Attributes:
    - Color: 0 (Blue), 0 (Blue), 0 (Blue) -> MATCH
    - Letter: C, A, A -> NO
    - Badge: 2, 3, 4 -> NO
- Multiplier: 1x (Only Color)
- Calculation: (2 + 3 + 4) × 1 = 9 points

Group B: Vertical (Col 1)
- Tiles: (1,1), (2,1), (3,1) -> 2C2, 1G2, 0K2
- Intersecting: Yes (contains 2C2 at 1,1)
- Shared Attributes:
    - Badge: 2, 2, 2 -> MATCH
    - Color: 2 (Green), 1 (Yellow), 0 (Blue) -> NO
    - Letter: C, G, K -> NO
- Multiplier: 1x (Only Badge)
- Calculation: (2 + 2 + 2) × 1 = 6 points

Group C: Diagonal (\ Direction)
- Tiles: (0,0), (1,1), (2,2) -> 0C2, 2C2, 2C2
- Intersecting: Yes (contains 2C2 at 1,1)
- Shared Attributes:
    - Letter: C, C, C -> MATCH
    - Badge: 2, 2, 2 -> MATCH
    - Color: 0 (Blue), 2 (Green), 2 (Green) -> NO
- Multiplier: 2x (Letter + Badge)
- Calculation: (2 + 2 + 2) × 2 = 12 points

---

3. Total Move Score
- Group A: 9
- Group B: 6
- Group C: 12
- Total: 27 points

Summary for User Review:
- Matching Groups: 3
- Highest Multiplier: 2x (Diagonal match sharing both Letter 'C' and Value 2)
- Total Move Score: 27
