import 'dart:math';
import 'package:flutter/material.dart';
import '../models/tile.dart';

class MatchGroup {
  final List<Tile> tiles;
  final String attribute;
  MatchGroup({required this.tiles, required this.attribute});
}

class GameState extends ChangeNotifier {
  final int rows = 5;
  final int cols = 4;
  List<Tile> tiles = [];
  int totalScore = 0;
  int lastMoveScore = 0;
  int optimumScore = 0;
  int previousOptimumScore = 0;
  
  // Quality tracking
  double sessionUserScore = 0;
  double sessionOptimumScore = 0;
  int sessionMoves = 0;
  DateTime? sessionStartTime;

  Duration get sessionDuration => sessionStartTime != null
      ? DateTime.now().difference(sessionStartTime!)
      : Duration.zero;

  String get sessionDurationString {
    final d = sessionDuration;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get moveQuality => sessionOptimumScore > 0 ? (sessionUserScore / sessionOptimumScore) : 0;

  bool isMatching = false;
  bool showOptimumCelebration = false;

  // Snapshot & Hint properties
  bool isSnapshotMode = false;
  bool isPausedForSnapshot = false;
  bool showHint = false;
  List<Tile> userMatchTiles = [];
  List<Tile> optimumMatchTiles = [];
  List<Tile> optimumSwapTiles = [];
  List<List<Tile>> currentMatches = [];

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

  void toggleSnapshotMode() {
    isSnapshotMode = !isSnapshotMode;
    notifyListeners();
  }

  void toggleHint() {
    showHint = !showHint;
    notifyListeners();
  }

  void initializeBoard() {
    tiles.clear();
    lastMoveScore = 0;
    optimumScore = 0;
    previousOptimumScore = 0;
    sessionUserScore = 0;
    sessionOptimumScore = 0;
    sessionMoves = 0;
    sessionStartTime = DateTime.now();
    isPausedForSnapshot = false;
    showHint = false;
    userMatchTiles.clear();
    optimumMatchTiles.clear();
    optimumSwapTiles.clear();
    currentMatches.clear();
    
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

  List<MatchGroup> findMatchesInternal({List<Tile>? customTiles, List<Tile>? activeTiles}) {
    final boardTiles = customTiles ?? tiles;
    List<MatchGroup> allMatches = [];

    Tile? getTile(int r, int c) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
      try {
        return boardTiles.firstWhere((t) => t.row == r && t.col == c);
      } catch (_) {
        return null;
      }
    }

    final directions = [
      const Point(0, 1),  // Horizontal
      const Point(1, 0),  // Vertical
      const Point(1, 1),  // Diagonal \
      const Point(1, -1), // Diagonal /
    ];

    for (var dir in directions) {
      for (var attr in ['color', 'letter', 'value']) {
        Set<String> visitedForAttrDir = {};
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            if (visitedForAttrDir.contains('$r,$c')) continue;

            Tile? startTile = getTile(r, c);
            if (startTile == null) continue;

            List<Tile> currentGroup = [startTile];
            int offset = 1;
            while (true) {
              Tile? nextT = getTile(r + offset * dir.x, c + offset * dir.y);
              if (nextT == null) break;

              bool match = false;
              if (attr == 'color' && nextT.color == startTile.color) match = true;
              if (attr == 'letter' && nextT.letter == startTile.letter) match = true;
              if (attr == 'value' && nextT.value == startTile.value) match = true;

              if (match) {
                currentGroup.add(nextT);
                offset++;
              } else {
                break;
              }
            }

            if (currentGroup.length >= 3) {
              allMatches.add(MatchGroup(tiles: currentGroup, attribute: attr));
              for (var m in currentGroup) {
                visitedForAttrDir.add('${m.row},${m.col}');
              }
            }
          }
        }
      }
    }

    if (activeTiles == null) return allMatches;

    List<MatchGroup> filteredMatches = [];
    Set<String> activeIds = activeTiles.map((t) => t.id).toSet();
    
    for (var match in allMatches) {
      if (match.tiles.any((t) => activeIds.contains(t.id))) {
        filteredMatches.add(match);
      }
    }
    
    return filteredMatches;
  }

  List<List<Tile>> findMatches({List<Tile>? customTiles, List<Tile>? activeTiles}) {
    return findMatchesInternal(customTiles: customTiles, activeTiles: activeTiles)
        .map((m) => m.tiles)
        .toList();
  }

  int calculateMatchesScore(List<List<Tile>> matches) {
    Map<String, ({List<Tile> tiles, Set<String> attributes})> uniqueGroups = {};
    for (var m in matches) {
      List<String> ids = m.map((t) => t.id).toList()..sort();
      String key = ids.join('|');
      
      bool sameColor = true;
      bool sameValue = true;
      bool sameLetter = true;
      for (int i = 1; i < m.length; i++) {
        if (m[i].color != m[0].color) sameColor = false;
        if (m[i].value != m[0].value) sameValue = false;
        if (m[i].letter != m[0].letter) sameLetter = false;
      }
      
      Set<String> attrs = {};
      if (sameColor) attrs.add('color');
      if (sameValue) attrs.add('value');
      if (sameLetter) attrs.add('letter');
      
      if (uniqueGroups.containsKey(key)) {
        uniqueGroups[key]!.attributes.addAll(attrs);
      } else {
        uniqueGroups[key] = (tiles: m, attributes: attrs);
      }
    }

    int totalScore = 0;
    uniqueGroups.forEach((key, data) {
      int sum = data.tiles.fold(0, (sum, t) => sum + t.value);
      int mult = 0;
      if (data.attributes.contains('color')) mult += 1;
      if (data.attributes.contains('value')) mult += 2;
      if (data.attributes.contains('letter')) mult += 3;
      totalScore += sum * mult;
    });
    return totalScore;
  }

  int calculateMatchesInternalScore(List<MatchGroup> matches) {
    Map<String, ({List<Tile> tiles, Set<String> attributes})> uniqueGroups = {};
    for (var m in matches) {
      List<String> ids = m.tiles.map((t) => t.id).toList()..sort();
      String key = ids.join('|');
      if (uniqueGroups.containsKey(key)) {
        uniqueGroups[key]!.attributes.add(m.attribute);
      } else {
        uniqueGroups[key] = (tiles: m.tiles, attributes: {m.attribute});
      }
    }

    int totalScore = 0;
    uniqueGroups.forEach((key, data) {
      int sum = data.tiles.fold(0, (sum, t) => sum + t.value);
      int mult = 0;
      if (data.attributes.contains('color')) mult += 1;
      if (data.attributes.contains('value')) mult += 2;
      if (data.attributes.contains('letter')) mult += 3;
      totalScore += sum * mult;
    });
    return totalScore;
  }

  Future<void> swapTiles(Tile t1, Tile t2) async {
    if (isMatching || isPausedForSnapshot) return;
    
    if ((t1.row == t2.row && (t1.col - t2.col).abs() == 1) ||
        (t1.col == t2.col && (t1.row - t2.row).abs() == 1)) {
      
      isMatching = true;
      showHint = false;
      notifyListeners();

      int idx1 = tiles.indexOf(t1);
      int idx2 = tiles.indexOf(t2);
      
      Tile newT1 = t1.copyWith(row: t2.row, col: t2.col);
      Tile newT2 = t2.copyWith(row: t1.row, col: t1.col);
      
      tiles[idx1] = newT1;
      tiles[idx2] = newT2;
      
      sessionMoves++;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));

      List<MatchGroup> matches = findMatchesInternal(activeTiles: [newT1, newT2]);
      if (matches.isEmpty) {
        // Swap back
        tiles[idx1] = t1;
        tiles[idx2] = t2;
        if (totalScore > 0) totalScore -= 1;
        lastMoveScore = -1;
        sessionUserScore -= 1;
        sessionOptimumScore += optimumScore;
        isMatching = false;
        notifyListeners();
      } else {
        int moveScore = calculateMatchesInternalScore(matches);
        lastMoveScore = moveScore;
        previousOptimumScore = optimumScore;
        sessionUserScore += moveScore;
        sessionOptimumScore += optimumScore;
        
        if (moveScore >= optimumScore) {
          showOptimumCelebration = true;
        }

        if (isSnapshotMode) {
          isPausedForSnapshot = true;
          currentMatches = matches.map((m) => m.tiles).toList();
          userMatchTiles = [];
          for (var match in matches) {
            userMatchTiles.addAll(match.tiles);
          }
          notifyListeners();
        } else {
          await processMatches(matches.map((m) => m.tiles).toList());
        }
      }
    }
  }

  Future<void> continueFromSnapshot() async {
    if (!isPausedForSnapshot) return;
    isPausedForSnapshot = false;
    userMatchTiles.clear();
    await processMatches(currentMatches);
  }

  Future<void> processMatches(List<List<Tile>> matches) async {
    int score = calculateMatchesScore(matches);
    totalScore += score;
    
    Set<String> toRemoveIds = {};
    for (var match in matches) {
      for (var t in match) {
        toRemoveIds.add(t.id);
      }
    }
    
    List<Tile> toRemoveTiles = tiles.where((t) => toRemoveIds.contains(t.id)).toList();
    List<Point<int>> refillPositions = toRemoveTiles.map((t) => Point(t.row, t.col)).toList();
    
    tiles.removeWhere((t) => toRemoveIds.contains(t.id));
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));

    for (var pos in refillPositions) {
      tiles.add(_generateRandomTile(pos.x, pos.y));
    }
    
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (showOptimumCelebration) {
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    
    isMatching = false;
    showOptimumCelebration = false;
    calculateOptimumScore();
    notifyListeners();
  }

  void calculateOptimumScore() {
    int maxScore = 0;
    List<Tile> bestTiles = [];
    List<Tile> bestSwap = [];
    
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (c < cols - 1) {
          var res = _simulateMove(r, c, r, c + 1);
          if (res.score > maxScore) {
            maxScore = res.score;
            bestTiles = res.matchedTiles;
            bestSwap = res.swapTiles;
          }
        }
        if (r < rows - 1) {
          var res = _simulateMove(r, c, r + 1, c);
          if (res.score > maxScore) {
            maxScore = res.score;
            bestTiles = res.matchedTiles;
            bestSwap = res.swapTiles;
          }
        }
      }
    }
    optimumScore = maxScore;
    optimumMatchTiles = bestTiles;
    optimumSwapTiles = bestSwap;
  }

  ({int score, List<Tile> matchedTiles, List<Tile> swapTiles}) _simulateMove(int r1, int c1, int r2, int c2) {
    List<Tile> tempTiles = List.from(tiles);
    int idx1 = tempTiles.indexWhere((t) => t.row == r1 && t.col == c1);
    int idx2 = tempTiles.indexWhere((t) => t.row == r2 && t.col == c2);
    
    Tile t1 = tempTiles[idx1];
    Tile t2 = tempTiles[idx2];
    
    Tile newT1 = t1.copyWith(row: r2, col: c2);
    Tile newT2 = t2.copyWith(row: r1, col: c1);
    
    tempTiles[idx1] = newT1;
    tempTiles[idx2] = newT2;

    List<MatchGroup> matches = findMatchesInternal(customTiles: tempTiles, activeTiles: [newT1, newT2]);
    if (matches.isEmpty) return (score: 0, matchedTiles: [], swapTiles: []);

    List<Tile> allMatchTiles = [];
    for (var m in matches) {
      allMatchTiles.addAll(m.tiles);
    }

    return (
      score: calculateMatchesInternalScore(matches), 
      matchedTiles: allMatchTiles, 
      swapTiles: [t1, t2]
    );
  }
}
