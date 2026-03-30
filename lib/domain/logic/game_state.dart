import 'dart:math';
import 'package:flutter/material.dart';
import '../models/tile.dart';

class GameState extends ChangeNotifier {
  final int rows = 5;
  final int cols = 4;
  List<Tile> tiles = [];
  int totalScore = 0;
  int lastMoveScore = 0;
  int optimumScore = 0;
  bool isMatching = false;
  bool showOptimumCelebration = false;

  final Random _random = Random();

  final List<Color> colors = [
    Colors.blue,
    Colors.yellow,
    Colors.green,
    Colors.purple,
    Colors.pink, // Rose
  ];

  int _idCounter = 0;

  GameState() {
    initializeBoard();
  }

  void initializeBoard() {
    tiles.clear();
    lastMoveScore = 0;
    // Generate board. We don't check for initial matches anymore 
    // because they don't auto-match.
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        tiles.add(_generateRandomTile(r, c));
      }
    }
    
    calculateOptimumScore();
    notifyListeners();
  }

  Tile _generateRandomTile(int r, int c) {
    Color color = colors[_random.nextInt(colors.length)];
    String letter = String.fromCharCode(65 + _random.nextInt(26)); // A-Z
    _idCounter++;
    return Tile(
      id: 'tile_$_idCounter',
      row: r,
      col: c,
      color: color,
      letter: letter,
      value: _random.nextInt(9) + 1,
    );
  }

  List<List<Tile>> findMatches({List<Tile>? customTiles, List<Tile>? activeTiles}) {
    final boardTiles = customTiles ?? tiles;
    List<List<Tile>> allMatches = [];

    // Helper to get tile at (r, c)
    Tile? getTile(int r, int c) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
      try {
        return boardTiles.firstWhere((t) => t.row == r && t.col == c);
      } catch (_) {
        return null;
      }
    }

    final List<Point<int>> directions = [
      const Point(0, 1),  // Horizontal
      const Point(1, 0),  // Vertical
      const Point(1, 1),  // Diagonal \
      const Point(1, -1), // Diagonal /
    ];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (var dir in directions) {
          Tile? t1 = getTile(r, c);
          Tile? t2 = getTile(r + dir.x, c + dir.y);
          Tile? t3 = getTile(r + 2 * dir.x, c + 2 * dir.y);

          if (t1 == null || t2 == null || t3 == null) continue;

          bool matchColor = t1.color == t2.color && t1.color == t3.color;
          bool matchLetter = t1.letter == t2.letter && t1.letter == t3.letter;
          bool matchBadge = t1.value == t2.value && t1.value == t3.value;

          if (matchColor || matchLetter || matchBadge) {
            List<Tile> match = [t1, t2, t3];
            int offset = 3;
            while (true) {
              Tile? nextT = getTile(r + offset * dir.x, c + offset * dir.y);
              if (nextT == null) break;

              bool stillMatch = false;
              if (matchColor && nextT.color == t1.color) stillMatch = true;
              if (matchLetter && nextT.letter == t1.letter) stillMatch = true;
              if (matchBadge && nextT.value == t1.value) stillMatch = true;

              if (stillMatch) {
                match.add(nextT);
                offset++;
              } else {
                break;
              }
            }
            allMatches.add(match);
          }
        }
      }
    }

    if (activeTiles == null) return allMatches;

    // Filter matches to only those intersecting with activeTiles
    List<List<Tile>> filteredMatches = [];
    Set<String> activeIds = activeTiles.map((t) => t.id).toSet();
    
    for (var match in allMatches) {
      if (match.any((t) => activeIds.contains(t.id))) {
        filteredMatches.add(match);
      }
    }
    
    return filteredMatches;
  }

  int calculateMatchesScore(List<List<Tile>> matches) {
    int totalMoveScore = 0;
    for (var match in matches) {
      int sumBadges = match.fold(0, (sum, tile) => sum + tile.value);
      
      bool allSameColor = true;
      bool allSameLetter = true;
      bool allSameBadge = true;

      Color firstColor = match[0].color;
      String firstLetter = match[0].letter;
      int firstBadge = match[0].value;

      for (var tile in match) {
        if (tile.color != firstColor) allSameColor = false;
        if (tile.letter != firstLetter) allSameLetter = false;
        if (tile.value != firstBadge) allSameBadge = false;
      }

      int multiplier = 0;
      if (allSameColor) multiplier++;
      if (allSameLetter) multiplier++;
      if (allSameBadge) multiplier++;

      totalMoveScore += sumBadges * multiplier;
    }
    return totalMoveScore;
  }

  Future<void> swapTiles(Tile t1, Tile t2) async {
    if (isMatching) return;
    
    if ((t1.row == t2.row && (t1.col - t2.col).abs() == 1) ||
        (t1.col == t2.col && (t1.row - t2.row).abs() == 1)) {
      
      isMatching = true;
      notifyListeners();

      int idx1 = tiles.indexOf(t1);
      int idx2 = tiles.indexOf(t2);
      
      Tile newT1 = t1.copyWith(row: t2.row, col: t2.col);
      Tile newT2 = t2.copyWith(row: t1.row, col: t1.col);
      
      tiles[idx1] = newT1;
      tiles[idx2] = newT2;
      
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));

      List<List<Tile>> matches = findMatches(activeTiles: [newT1, newT2]);
      if (matches.isEmpty) {
        // Swap back
        tiles[idx1] = t1;
        tiles[idx2] = t2;
        
        // False move penalty
        if (totalScore > 0) totalScore -= 1;
        lastMoveScore = -1;
        
        isMatching = false;
        notifyListeners();
      } else {
        int moveScore = calculateMatchesScore(matches);
        lastMoveScore = moveScore;
        if (moveScore >= optimumScore) {
          showOptimumCelebration = true;
        }
        await processMatches(matches);
      }
    }
  }

  Future<void> processMatches(List<List<Tile>> matches) async {
    // We only process the matches passed in. No more cascade loops.
    int score = calculateMatchesScore(matches);
    totalScore += score;
    
    Set<Tile> toRemove = {};
    for (var match in matches) {
      toRemove.addAll(match);
    }
    
    List<Point<int>> refillPositions = toRemove.map((t) => Point(t.row, t.col)).toList();
    
    tiles.removeWhere((t) => toRemove.contains(t));
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));

    for (var pos in refillPositions) {
      tiles.add(_generateRandomTile(pos.x, pos.y));
    }
    
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    
    isMatching = false;
    showOptimumCelebration = false;
    calculateOptimumScore();
    notifyListeners();
  }

  void calculateOptimumScore() {
    int maxScore = 0;
    
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (c < cols - 1) {
          maxScore = max(maxScore, _simulateMove(r, c, r, c + 1));
        }
        if (r < rows - 1) {
          maxScore = max(maxScore, _simulateMove(r, c, r + 1, c));
        }
      }
    }
    optimumScore = maxScore;
  }

  int _simulateMove(int r1, int c1, int r2, int c2) {
    List<Tile> tempTiles = List.from(tiles);
    int idx1 = tempTiles.indexWhere((t) => t.row == r1 && t.col == c1);
    int idx2 = tempTiles.indexWhere((t) => t.row == r2 && t.col == c2);
    
    Tile t1 = tempTiles[idx1];
    Tile t2 = tempTiles[idx2];
    
    Tile newT1 = t1.copyWith(row: r2, col: c2);
    Tile newT2 = t2.copyWith(row: r1, col: c1);
    
    tempTiles[idx1] = newT1;
    tempTiles[idx2] = newT2;

    List<List<Tile>> matches = findMatches(customTiles: tempTiles, activeTiles: [newT1, newT2]);
    if (matches.isEmpty) return 0;

    return calculateMatchesScore(matches);
  }
}
