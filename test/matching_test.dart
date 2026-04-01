import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/domain/logic/game_state.dart';
import '../lib/domain/models/tile.dart';

void main() {
  final GameState gameState = GameState();

  /// Helper to create a board from a human-readable string.
  List<Tile> parseBoard(String grid) {
    List<Tile> tiles = [];
    List<String> rows = grid.trim().split('\n').map((e) => e.trim()).toList();
    for (int r = 0; r < rows.length; r++) {
      List<String> cols = rows[r].split(RegExp(r'\s+'));
      for (int c = 0; c < cols.length; c++) {
        String cell = cols[c];
        if (cell.length < 3) continue;
        int colorIdx = int.parse(cell[0]);
        String letter = cell[1];
        int value = int.parse(cell[2]);
        tiles.add(Tile(
          id: 't_${r}_$c',
          row: r,
          col: c,
          color: gameState.colors[colorIdx],
          letter: letter,
          value: value,
        ));
      }
    }
    return tiles;
  }

  group('Match Calculation Logic - Verified Boards', () {
    test('Case 0: Agreed Example Move (Score 51)', () async {
      // Swapped (0,1) and (1,1)
      const String gridAfterMove = '''
        0C2  0A3  0A4  1X5
        1B1  2C2  3D3  4E4
        0F5  1G2  2C2  3I8
        4J9  0K2  1L2  2M3
        3N4  4O5  0P6  1Q7
      ''';

      final tiles = parseBoard(gridAfterMove);
      
      // The two flipped tiles
      final tile1 = tiles.firstWhere((t) => t.row == 0 && t.col == 1);
      final tile2 = tiles.firstWhere((t) => t.row == 1 && t.col == 1);

      final matches = gameState.findMatches(
        customTiles: tiles, 
        activeTiles: [tile1, tile2],
      );

      // Verify groups (New rules: Color=1, Value/Badge=2, Letter=3):
      // 1. Horiz (0,0)-(0,2) [Color 0]. Multiplier 1. Sum 2+3+4=9. Score 9.
      // 2. Vert (1,1)-(3,1) [Badge 2]. Multiplier 2. Sum 2+2+2=6. Score 12.
      // 3. Diag (0,0)-(2,2) [Letter C, Badge 2]. Multiplier 2+3=5. Sum 2+2+2=6. Score 30.
      // Total: 9 + 12 + 30 = 51.

      final score = gameState.calculateMatchesScore(matches);
      
      expect(score, 51, reason: 'Case 0 failed. Expected 51, got $score');
    });

    test('Case 1: Multiple Attribute Match (Multiplier 1+2+3=6x)', () async {
      const String grid = '''
        0A5  0A5  0A5  1X1
        1B2  2C3  3D4  4E5
        0F1  1G2  2H3  3I4
        4J5  0K6  1L7  2M8
        3N9  4O1  0P2  1Q3
      ''';
      final tiles = parseBoard(grid);
      final tile1 = tiles.firstWhere((t) => t.row == 0 && t.col == 0);
      
      final matches = gameState.findMatches(customTiles: tiles, activeTiles: [tile1]);
      final score = gameState.calculateMatchesScore(matches);
      
      // (5+5+5) * (1+2+3) = 15 * 6 = 90
      expect(score, 90);
    });

    test('Case 2: Intersecting Matches (Summed)', () async {
      const String grid = '''
        0A1  0B2  0C3  4Z9
        0D4  1X1  2Y2  3W3
        0E5  4V4  1U5  2T6
        4S7  0R8  1Q9  2P1
        3O2  4N3  0M4  1L5
      ''';
      final tiles = parseBoard(grid);
      // Flipped tile (0,0) intersects Row 0 and Col 0
      final tile1 = tiles.firstWhere((t) => t.row == 0 && t.col == 0);
      
      final matches = gameState.findMatches(customTiles: tiles, activeTiles: [tile1]);
      final score = gameState.calculateMatchesScore(matches);
      
      // Row 0: (1+2+3)*1 = 6
      // Col 0: (1+4+5)*1 = 10
      // Total: 16
      expect(score, 16);
    });

    test('Case 3: Diagonal Match Only', () async {
      const String grid = '''
        0A1  1B2  2C3  3D4
        1E5  0F6  3G7  4H8
        2I9  1J1  0K2  3L3
        4M4  0N5  1O6  2P7
        3Q8  4R9  0S1  1T2
      ''';
      final tiles = parseBoard(grid);
      final tile1 = tiles.firstWhere((t) => t.row == 1 && t.col == 1);
      
      final matches = gameState.findMatches(customTiles: tiles, activeTiles: [tile1]);
      final score = gameState.calculateMatchesScore(matches);
      
      // Diag (0,0)-(2,2) Color 0: (1+6+2)*1 = 9
      expect(score, 9);
    });

    test('Case 4: False Move (No Match)', () async {
      const String grid = '''
        0A1  1B2  2C3  3D4
        4E5  1F6  0G7  2H8
        3I9  4J1  0K2  1L3
        2M4  3N5  4O6  0P7
        1Q8  2R9  3S1  4T2
      ''';
      final tiles = parseBoard(grid);
      final tile1 = tiles.firstWhere((t) => t.row == 0 && t.col == 0);
      final tile2 = tiles.firstWhere((t) => t.row == 0 && t.col == 1);
      
      final matches = gameState.findMatches(customTiles: tiles, activeTiles: [tile1, tile2]);
      final score = gameState.calculateMatchesScore(matches);
      
      expect(score, 0);
    });
  });
}
