import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:badger/domain/logic/game_state.dart';
import 'package:badger/domain/models/tile.dart';

/// Helper to create a tile with minimal boilerplate.
Tile makeTile({
  required int row,
  required int col,
  Color color = Colors.grey,
  String letter = 'X',
  int value = 1,
  String? id,
}) {
  return Tile(
    id: id ?? 'tile_${row}_$col',
    row: row,
    col: col,
    color: color,
    letter: letter,
    value: value,
  );
}

/// Builds a full 5x4 board of fully unique tiles, then applies overrides.
/// Each background tile has a unique color, letter, and value so no accidental matches.
List<Tile> buildBoard(List<Tile> overrides) {
  final Map<String, Tile> board = {};
  int counter = 0;
  for (int r = 0; r < 5; r++) {
    for (int c = 0; c < 4; c++) {
      counter++;
      board['$r,$c'] = Tile(
        id: 'bg_$counter',
        row: r,
        col: c,
        color: Color(0xFF000000 + counter * 7919), // unique color per tile
        letter: String.fromCharCode(counter + 128),
        value: 100 + counter,
      );
    }
  }
  for (var t in overrides) {
    board['${t.row},${t.col}'] = t;
  }
  return board.values.toList();
}

void main() {
  late GameState gameState;

  setUp(() {
    gameState = GameState();
  });

  group('findMatches — match detection', () {
    test('finds horizontal 3-match by color', () {
      final tiles = buildBoard([
        makeTile(row: 0, col: 0, color: Colors.blue),
        makeTile(row: 0, col: 1, color: Colors.blue),
        makeTile(row: 0, col: 2, color: Colors.blue),
      ]);

      final matches = gameState.findMatches(customTiles: tiles);
      final colorMatches = matches.where((m) =>
          m.length >= 3 && m.every((t) => t.color == Colors.blue)).toList();

      expect(colorMatches.length, 1);
      expect(colorMatches.first.length, 3);
    });

    test('finds vertical 3-match by color', () {
      final tiles = buildBoard([
        makeTile(row: 0, col: 0, color: Colors.red),
        makeTile(row: 1, col: 0, color: Colors.red),
        makeTile(row: 2, col: 0, color: Colors.red),
      ]);

      final matches = gameState.findMatches(customTiles: tiles);
      final colorMatches = matches.where((m) =>
          m.length >= 3 && m.every((t) => t.color == Colors.red)).toList();

      expect(colorMatches.length, 1);
      expect(colorMatches.first.length, 3);
    });

    test('finds diagonal 3-match by color', () {
      final tiles = buildBoard([
        makeTile(row: 0, col: 0, color: Colors.green),
        makeTile(row: 1, col: 1, color: Colors.green),
        makeTile(row: 2, col: 2, color: Colors.green),
      ]);

      final matches = gameState.findMatches(customTiles: tiles);
      final colorMatches = matches.where((m) =>
          m.length >= 3 && m.every((t) => t.color == Colors.green)).toList();

      expect(colorMatches.length, 1);
      expect(colorMatches.first.length, 3);
    });

    test('finds 3-match by letter', () {
      final tiles = buildBoard([
        makeTile(row: 2, col: 0, color: Colors.red, letter: 'A', value: 3),
        makeTile(row: 2, col: 1, color: Colors.blue, letter: 'A', value: 5),
        makeTile(row: 2, col: 2, color: Colors.green, letter: 'A', value: 7),
      ]);

      final matches = gameState.findMatches(customTiles: tiles);
      final letterMatches = matches.where((m) =>
          m.length >= 3 && m.every((t) => t.letter == 'A')).toList();

      expect(letterMatches.length, 1);
    });

    test('finds 3-match by value', () {
      final tiles = buildBoard([
        makeTile(row: 1, col: 0, color: Colors.red, letter: 'A', value: 5),
        makeTile(row: 1, col: 1, color: Colors.blue, letter: 'B', value: 5),
        makeTile(row: 1, col: 2, color: Colors.green, letter: 'C', value: 5),
      ]);

      final matches = gameState.findMatches(customTiles: tiles);
      final valueMatches = matches.where((m) =>
          m.length >= 3 && m.every((t) => t.value == 5)).toList();

      expect(valueMatches.length, 1);
    });

    test('returns no matches when none exist', () {
      // Default board from buildBoard has all unique tiles.
      final tiles = buildBoard([]);

      final matches = gameState.findMatches(customTiles: tiles);
      expect(matches, isEmpty);
    });

    test('finds two independent matches on the same board', () {
      final tiles = buildBoard([
        // Horizontal blue match row 0
        makeTile(row: 0, col: 0, color: Colors.blue, letter: 'A', value: 1),
        makeTile(row: 0, col: 1, color: Colors.blue, letter: 'B', value: 2),
        makeTile(row: 0, col: 2, color: Colors.blue, letter: 'C', value: 3),
        // Horizontal red match row 3
        makeTile(row: 3, col: 0, color: Colors.red, letter: 'D', value: 4),
        makeTile(row: 3, col: 1, color: Colors.red, letter: 'E', value: 5),
        makeTile(row: 3, col: 2, color: Colors.red, letter: 'F', value: 6),
      ]);

      final matches = gameState.findMatches(customTiles: tiles);
      expect(matches.length, 2);
    });
  });

  group('findMatches — no duplicate subset matches', () {
    test('4-tile diagonal match is found exactly once', () {
      final tiles = buildBoard([
        makeTile(row: 0, col: 0, color: Colors.blue, letter: 'W', value: 1),
        makeTile(row: 1, col: 1, color: Colors.blue, letter: 'F', value: 1),
        makeTile(row: 2, col: 2, color: Colors.blue, letter: 'M', value: 7),
        makeTile(row: 3, col: 3, color: Colors.blue, letter: 'Z', value: 2),
      ]);

      final matches = gameState.findMatches(customTiles: tiles);
      final blueMatches = matches.where((m) =>
          m.every((t) => t.color == Colors.blue)).toList();

      expect(blueMatches.length, 1, reason: 'A 4-tile match should not produce a subset 3-tile match');
      expect(blueMatches.first.length, 4);
    });

    test('4-tile horizontal match is found exactly once', () {
      final tiles = buildBoard([
        makeTile(row: 0, col: 0, color: Colors.purple, letter: 'A', value: 2),
        makeTile(row: 0, col: 1, color: Colors.purple, letter: 'B', value: 3),
        makeTile(row: 0, col: 2, color: Colors.purple, letter: 'C', value: 4),
        makeTile(row: 0, col: 3, color: Colors.purple, letter: 'D', value: 5),
      ]);

      final matches = gameState.findMatches(customTiles: tiles);
      final purpleMatches = matches.where((m) =>
          m.every((t) => t.color == Colors.purple)).toList();

      expect(purpleMatches.length, 1);
      expect(purpleMatches.first.length, 4);
    });

    test('5-tile vertical match is found exactly once', () {
      final tiles = buildBoard([
        makeTile(row: 0, col: 0, color: Colors.yellow, letter: 'A', value: 1),
        makeTile(row: 1, col: 0, color: Colors.yellow, letter: 'B', value: 2),
        makeTile(row: 2, col: 0, color: Colors.yellow, letter: 'C', value: 3),
        makeTile(row: 3, col: 0, color: Colors.yellow, letter: 'D', value: 4),
        makeTile(row: 4, col: 0, color: Colors.yellow, letter: 'E', value: 5),
      ]);

      final matches = gameState.findMatches(customTiles: tiles);
      final yellowMatches = matches.where((m) =>
          m.every((t) => t.color == Colors.yellow)).toList();

      expect(yellowMatches.length, 1);
      expect(yellowMatches.first.length, 5);
    });
  });

  group('calculateMatchesScore — scoring rules', () {
    test('color-only match: sum * 1', () {
      final match = [
        makeTile(row: 0, col: 0, color: Colors.blue, letter: 'A', value: 3),
        makeTile(row: 0, col: 1, color: Colors.blue, letter: 'B', value: 5),
        makeTile(row: 0, col: 2, color: Colors.blue, letter: 'C', value: 7),
      ];

      final score = gameState.calculateMatchesScore([match]);
      // color: (3+5+7)*1 = 15
      expect(score, 15);
    });

    test('value-only match: sum * 2', () {
      final match = [
        makeTile(row: 0, col: 0, color: Colors.red, letter: 'A', value: 4),
        makeTile(row: 0, col: 1, color: Colors.blue, letter: 'B', value: 4),
        makeTile(row: 0, col: 2, color: Colors.green, letter: 'C', value: 4),
      ];

      final score = gameState.calculateMatchesScore([match]);
      // badge: (4+4+4)*2 = 24
      expect(score, 24);
    });

    test('letter-only match: sum * 3', () {
      final match = [
        makeTile(row: 0, col: 0, color: Colors.red, letter: 'Z', value: 1),
        makeTile(row: 0, col: 1, color: Colors.blue, letter: 'Z', value: 3),
        makeTile(row: 0, col: 2, color: Colors.green, letter: 'Z', value: 9),
      ];

      final score = gameState.calculateMatchesScore([match]);
      // letter: (1+3+9)*3 = 39
      expect(score, 39);
    });

    test('color + letter match: sum * (1+3) = sum * 4', () {
      final match = [
        makeTile(row: 0, col: 0, color: Colors.blue, letter: 'Q', value: 3),
        makeTile(row: 0, col: 1, color: Colors.blue, letter: 'Q', value: 5),
        makeTile(row: 0, col: 2, color: Colors.blue, letter: 'Q', value: 7),
      ];

      final score = gameState.calculateMatchesScore([match]);
      // color: 15*1 + letter: 15*3 = 15 + 45 = 60
      expect(score, 60);
    });

    test('color + value match: sum * (1+2) = sum * 3', () {
      final match = [
        makeTile(row: 0, col: 0, color: Colors.blue, letter: 'A', value: 4),
        makeTile(row: 0, col: 1, color: Colors.blue, letter: 'B', value: 4),
        makeTile(row: 0, col: 2, color: Colors.blue, letter: 'C', value: 4),
      ];

      final score = gameState.calculateMatchesScore([match]);
      // color: 12*1 + badge: 12*2 = 12 + 24 = 36
      expect(score, 36);
    });

    test('all three attributes match: sum * (1+2+3) = sum * 6', () {
      final match = [
        makeTile(row: 0, col: 0, color: Colors.blue, letter: 'Q', value: 7),
        makeTile(row: 0, col: 1, color: Colors.blue, letter: 'Q', value: 7),
        makeTile(row: 0, col: 2, color: Colors.blue, letter: 'Q', value: 7),
      ];

      final score = gameState.calculateMatchesScore([match]);
      // color: 21*1 + badge: 21*2 + letter: 21*3 = 21 + 42 + 63 = 126
      expect(score, 126);
    });

    test('multiple match groups sum their scores', () {
      final match1 = [
        makeTile(row: 0, col: 0, color: Colors.blue, letter: 'A', value: 2),
        makeTile(row: 0, col: 1, color: Colors.blue, letter: 'B', value: 3),
        makeTile(row: 0, col: 2, color: Colors.blue, letter: 'C', value: 5),
      ];
      final match2 = [
        makeTile(row: 3, col: 0, color: Colors.red, letter: 'D', value: 1),
        makeTile(row: 3, col: 1, color: Colors.red, letter: 'E', value: 4),
        makeTile(row: 3, col: 2, color: Colors.red, letter: 'F', value: 6),
      ];

      final score = gameState.calculateMatchesScore([match1, match2]);
      // color-only each: 10*1 + 11*1 = 21
      expect(score, 21);
    });

    test('4-tile color match scores correctly (no double count)', () {
      final tiles = buildBoard([
        makeTile(row: 0, col: 0, color: Colors.blue, letter: 'W', value: 1),
        makeTile(row: 1, col: 1, color: Colors.blue, letter: 'F', value: 1),
        makeTile(row: 2, col: 2, color: Colors.blue, letter: 'M', value: 7),
        makeTile(row: 3, col: 3, color: Colors.blue, letter: 'Z', value: 2),
      ]);

      final matches = gameState.findMatches(customTiles: tiles);
      final blueMatches = matches.where((m) =>
          m.every((t) => t.color == Colors.blue)).toList();
      final score = gameState.calculateMatchesScore(blueMatches);

      // color-only: (1+1+7+2)*1 = 11
      expect(score, 11);
    });

    test('empty match list scores zero', () {
      final score = gameState.calculateMatchesScore([]);
      expect(score, 0);
    });
  });

  group('findMatches — activeTiles filter', () {
    test('only returns matches involving active tiles', () {
      final blueTiles = [
        makeTile(row: 0, col: 0, color: Colors.blue, letter: 'A', value: 1, id: 'a'),
        makeTile(row: 0, col: 1, color: Colors.blue, letter: 'B', value: 2, id: 'b'),
        makeTile(row: 0, col: 2, color: Colors.blue, letter: 'C', value: 3, id: 'c'),
      ];
      final redTiles = [
        makeTile(row: 3, col: 0, color: Colors.red, letter: 'D', value: 4, id: 'd'),
        makeTile(row: 3, col: 1, color: Colors.red, letter: 'E', value: 5, id: 'e'),
        makeTile(row: 3, col: 2, color: Colors.red, letter: 'F', value: 6, id: 'f'),
      ];
      final tiles = buildBoard([...blueTiles, ...redTiles]);

      // Only pass one blue tile as active — should only return the blue match
      final matches = gameState.findMatches(
        customTiles: tiles,
        activeTiles: [blueTiles.first],
      );

      expect(matches.length, 1);
      expect(matches.first.every((t) => t.color == Colors.blue), isTrue);
    });
  });
}
