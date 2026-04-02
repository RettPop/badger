import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smatcher/domain/models/game_mode.dart';

void main() {
  group('GameModeType enum properties', () {
    test('convenient mode has correct properties', () {
      const mode = GameModeType.convenient;
      expect(mode.name, 'Convenient');
      expect(mode.calculatesOptimum, isTrue);
      expect(mode.usesGravity, isFalse);
      expect(mode.allowsDragToAny, isFalse);
      expect(mode.isSnakeDrag, isFalse);
      expect(mode.hasScoreDrain, isFalse);
      expect(mode.highScoreGeneration, isFalse);
    });

    test('highScores mode has correct properties', () {
      const mode = GameModeType.highScores;
      expect(mode.name, 'High Scores');
      expect(mode.calculatesOptimum, isTrue);
      expect(mode.highScoreGeneration, isTrue);
      expect(mode.usesGravity, isFalse);
      expect(mode.allowsDragToAny, isFalse);
      expect(mode.isSnakeDrag, isFalse);
      expect(mode.hasScoreDrain, isFalse);
    });

    test('dropDown mode has correct properties', () {
      const mode = GameModeType.dropDown;
      expect(mode.name, 'Drop Down');
      expect(mode.usesGravity, isTrue);
      expect(mode.calculatesOptimum, isTrue);
      expect(mode.allowsDragToAny, isFalse);
      expect(mode.isSnakeDrag, isFalse);
      expect(mode.hasScoreDrain, isFalse);
      expect(mode.highScoreGeneration, isFalse);
    });

    test('simpleDrag mode has correct properties', () {
      const mode = GameModeType.simpleDrag;
      expect(mode.name, 'Simple Drag');
      expect(mode.allowsDragToAny, isTrue);
      expect(mode.calculatesOptimum, isFalse);
      expect(mode.usesGravity, isFalse);
      expect(mode.isSnakeDrag, isFalse);
      expect(mode.hasScoreDrain, isFalse);
      expect(mode.highScoreGeneration, isFalse);
    });

    test('snakeDrag mode has correct properties', () {
      const mode = GameModeType.snakeDrag;
      expect(mode.name, 'Snake Drag');
      expect(mode.allowsDragToAny, isTrue);
      expect(mode.isSnakeDrag, isTrue);
      expect(mode.calculatesOptimum, isFalse);
      expect(mode.usesGravity, isFalse);
      expect(mode.hasScoreDrain, isFalse);
      expect(mode.highScoreGeneration, isFalse);
    });

    test('arcade mode has correct properties', () {
      const mode = GameModeType.arcade;
      expect(mode.name, 'Arcade');
      expect(mode.hasScoreDrain, isTrue);
      expect(mode.calculatesOptimum, isTrue);
      expect(mode.usesGravity, isFalse);
      expect(mode.allowsDragToAny, isFalse);
      expect(mode.isSnakeDrag, isFalse);
      expect(mode.highScoreGeneration, isFalse);
    });

    test('all modes have non-empty name and valid icon', () {
      for (final mode in GameModeType.values) {
        expect(mode.name.isNotEmpty, isTrue,
            reason: '$mode should have a non-empty name');
        expect(mode.icon, isNotNull,
            reason: '$mode should have a valid icon');
        expect(mode.icon, isA<IconData>(),
            reason: '$mode icon should be an IconData');
      }
    });
  });
}
