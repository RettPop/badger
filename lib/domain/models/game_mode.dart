import 'package:flutter/material.dart';

enum GameModeType { convenient, highScores, dropDown, simpleDrag, snakeDrag, arcade }

extension GameModeTypeExtension on GameModeType {
  String get name {
    switch (this) {
      case GameModeType.convenient:
        return 'Convenient';
      case GameModeType.highScores:
        return 'High Scores (50+)';
      case GameModeType.dropDown:
        return 'Drop Down';
      case GameModeType.simpleDrag:
        return 'Simple Drag';
      case GameModeType.snakeDrag:
        return 'Snake Drag';
      case GameModeType.arcade:
        return 'Arcade';
    }
  }

  IconData get icon {
    switch (this) {
      case GameModeType.convenient:
        return Icons.spa;
      case GameModeType.highScores:
        return Icons.emoji_events;
      case GameModeType.dropDown:
        return Icons.arrow_downward;
      case GameModeType.simpleDrag:
        return Icons.swipe;
      case GameModeType.snakeDrag:
        return Icons.gesture;
      case GameModeType.arcade:
        return Icons.timer;
    }
  }

  bool get calculatesOptimum {
    switch (this) {
      case GameModeType.convenient:
      case GameModeType.highScores:
      case GameModeType.dropDown:
      case GameModeType.arcade:
        return true;
      case GameModeType.simpleDrag:
      case GameModeType.snakeDrag:
        return false;
    }
  }

  bool get usesGravity {
    return this == GameModeType.dropDown;
  }

  bool get allowsDragToAny {
    switch (this) {
      case GameModeType.simpleDrag:
      case GameModeType.snakeDrag:
        return true;
      default:
        return false;
    }
  }

  bool get isSnakeDrag {
    return this == GameModeType.snakeDrag;
  }

  bool get hasScoreDrain {
    return this == GameModeType.arcade;
  }

  bool get highScoreGeneration {
    return this == GameModeType.highScores;
  }
}
