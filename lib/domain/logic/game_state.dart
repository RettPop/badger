import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_mode.dart';
import '../models/tile.dart';

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

  // Game Mode
  GameModeType currentMode = GameModeType.convenient;

  // Arcade timer
  Timer? _arcadeTimer;
  bool isDialogOpen = false;

  // Snake drag state
  List<Tile> snakeDragPath = [];
  Tile? snakeDragOrigin;
  List<Tile> snakeDragOriginalTiles = [];

  late final Random _random;

  final List<Color> colors = [
    Colors.blue,
    Colors.yellow,
    Colors.green,
    Colors.purple,
    Colors.pink, // Rose
  ];

  int _idCounter = 0;

  GameState({Random? random}) {
    _random = random ?? Random();
    initializeBoard();
  }

  @override
  void dispose() {
    _arcadeTimer?.cancel();
    _arcadeTimer = null;
    super.dispose();
  }

  void setMode(GameModeType mode) {
    _arcadeTimer?.cancel();
    _arcadeTimer = null;
    currentMode = mode;
    totalScore = 0;
    initializeBoard(resetSession: true);
  }

  void toggleSnapshotMode() {
    isSnapshotMode = !isSnapshotMode;
    notifyListeners();
  }

  void toggleHint() {
    showHint = !showHint;
    notifyListeners();
  }

  void initializeBoard({bool deductScore = false, bool resetSession = true}) {
    if (deductScore) {
      totalScore = max(0, totalScore - optimumScore);
    }
    tiles.clear();

    if (resetSession) {
      lastMoveScore = 0;
      optimumScore = 0;
      previousOptimumScore = 0;
      sessionUserScore = 0;
      sessionOptimumScore = 0;
      sessionMoves = 0;
      sessionStartTime = DateTime.now();
    }

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

    if (currentMode.highScoreGeneration) {
      _applyHighScoreConstraintToBoard();
    }

    calculateOptimumScore();

    // Start arcade timer if in arcade mode
    if (currentMode.hasScoreDrain) {
      _startArcadeTimer();
    }

    notifyListeners();
  }

  void _startArcadeTimer() {
    _arcadeTimer?.cancel();
    _arcadeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isPausedForSnapshot && !isDialogOpen) {
        if (totalScore > 0) {
          totalScore -= 1;
          notifyListeners();
        }
      }
    });
  }

  /// Applies high-score constraint to the full board during initializeBoard for mode 2.
  /// Tries up to 20 full-board regenerations to get optimumScore >= 50.
  void _applyHighScoreConstraintToBoard() {
    calculateOptimumScore();
    if (optimumScore >= 50) return;

    for (int attempt = 0; attempt < 20; attempt++) {
      tiles.clear();
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          tiles.add(_generateRandomTile(r, c));
        }
      }
      calculateOptimumScore();
      if (optimumScore >= 50) return;
    }
    // If still fails after 20 attempts, use the last generated result as-is
  }

  /// Generates tiles for the given positions with high-score constraint (mode 2).
  /// Retries up to 20 times replacing only the new tiles, then up to 20 full-board retries.
  void _generateTilesWithHighScoreConstraint(List<Point<int>> positions) {
    // Phase 1: partial retries - only regenerate the given positions
    for (int attempt = 0; attempt < 20; attempt++) {
      // Remove any tiles at the target positions
      tiles.removeWhere((t) => positions.any((p) => p.x == t.row && p.y == t.col));
      // Generate new tiles for the positions
      for (var pos in positions) {
        tiles.add(_generateRandomTile(pos.x, pos.y));
      }
      calculateOptimumScore();
      if (optimumScore >= 50) return;
    }

    // Phase 2: full-board retries
    for (int attempt = 0; attempt < 20; attempt++) {
      tiles.clear();
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          tiles.add(_generateRandomTile(r, c));
        }
      }
      calculateOptimumScore();
      if (optimumScore >= 50) return;
    }
    // If still fails, use the last generated result as-is
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
    Set<String> visited = {}; // Use keys to prevent redundant matches in one scan

    Tile? getTile(int r, int c) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
      try {
        return boardTiles.firstWhere((t) => t.row == r && t.col == c);
      } catch (_) {
        return null;
      }
    }

    final List<Point<int>> directions = [
      const Point(0, 1),
      const Point(1, 0),
      const Point(1, 1),
      const Point(1, -1),
    ];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (var dir in directions) {
          String startKey = '$r,$c,${dir.x},${dir.y}';
          if (visited.contains(startKey)) continue;

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

            // Mark these tiles as visited for this direction to avoid overlapping subsets
            for (var tile in match) {
              visited.add('${tile.row},${tile.col},${dir.x},${dir.y}');
            }

            allMatches.add(match);
          }
        }
      }
    }

    if (activeTiles == null) return allMatches;

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
      if (allSameColor) multiplier += 1;
      if (allSameBadge) multiplier += 2;
      if (allSameLetter) multiplier += 3;

      totalMoveScore += sumBadges * multiplier;
    }
    return totalMoveScore;
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

      List<List<Tile>> matches = findMatches(activeTiles: [newT1, newT2]);
      if (matches.isEmpty) {
        // Swap back
        tiles[idx1] = t1;
        tiles[idx2] = t2;

        // False move penalty
        if (totalScore > 0) totalScore -= 1;
        lastMoveScore = -1;

        // Track quality for false move
        sessionUserScore -= 1;
        sessionOptimumScore += optimumScore;

        isMatching = false;
        notifyListeners();
      } else {
        int moveScore = calculateMatchesScore(matches);
        lastMoveScore = moveScore;
        previousOptimumScore = optimumScore; // Capture before move

        // Track quality for successful move
        sessionUserScore += moveScore;
        sessionOptimumScore += optimumScore;

        if (currentMode.calculatesOptimum && moveScore >= optimumScore) {
          showOptimumCelebration = true;
        }

        if (isSnapshotMode) {
          isPausedForSnapshot = true;
          currentMatches = matches;
          userMatchTiles = [];
          for (var match in matches) {
            userMatchTiles.addAll(match);
          }
          notifyListeners();
        } else {
          await processMatches(matches);
        }
      }
    }
  }

  /// Mode 4: Any-position swap (no adjacency check)
  Future<void> swapTilesAny(Tile t1, Tile t2) async {
    if (isMatching || isPausedForSnapshot) return;

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

    List<List<Tile>> matches = findMatches(activeTiles: [newT1, newT2]);
    if (matches.isEmpty) {
      // Swap back
      tiles[idx1] = t1;
      tiles[idx2] = t2;

      // False move penalty
      if (totalScore > 0) totalScore -= 1;
      lastMoveScore = -1;
      sessionUserScore -= 1;

      isMatching = false;
      notifyListeners();
    } else {
      int moveScore = calculateMatchesScore(matches);
      lastMoveScore = moveScore;
      sessionUserScore += moveScore;

      // Do NOT set showOptimumCelebration — guard with calculatesOptimum
      if (currentMode.calculatesOptimum && moveScore >= optimumScore) {
        showOptimumCelebration = true;
      }

      if (isSnapshotMode) {
        isPausedForSnapshot = true;
        currentMatches = matches;
        userMatchTiles = [];
        for (var match in matches) {
          userMatchTiles.addAll(match);
        }
        notifyListeners();
      } else {
        await processMatches(matches);
      }
    }
  }

  /// Mode 5: Start snake drag
  void startSnakeDrag(Tile tile) {
    snakeDragOrigin = tile;
    snakeDragOriginalTiles = tiles.map((t) => Tile(
      id: t.id,
      row: t.row,
      col: t.col,
      color: t.color,
      letter: t.letter,
      value: t.value,
    )).toList();
    snakeDragPath = [tile];
    notifyListeners();
  }

  /// Mode 5: Update snake drag when the finger enters a new grid cell.
  /// Called with the row/col of the cell the finger is currently over.
  void updateSnakeDragAt(int row, int col) {
    if (snakeDragPath.isEmpty || snakeDragOrigin == null) return;

    // Find the tile currently at this grid cell
    final hoveredIdx = tiles.indexWhere((t) => t.row == row && t.col == col);
    if (hoveredIdx < 0) return;
    final Tile hoveredTile = tiles[hoveredIdx];

    // Ignore if it's the dragged tile itself (finger still on same cell)
    if (hoveredTile.id == snakeDragOrigin!.id) return;

    // Check if hoveredTile is already in the path (backtrack — always allowed)
    int existingIndex = snakeDragPath.indexWhere((t) => t.id == hoveredTile.id);

    if (existingIndex < 0) {
      // For extending: only allow if adjacent to dragged tile's current model position
      Tile draggedTile = tiles.firstWhere((t) => t.id == snakeDragOrigin!.id);
      bool adjacent = (draggedTile.row == row && (draggedTile.col - col).abs() == 1) ||
                      (draggedTile.col == col && (draggedTile.row - row).abs() == 1);
      if (!adjacent) return;
    }

    if (existingIndex >= 0) {
      // Backtrack: hovering over a tile already in the path means "undo back to
      // before this tile was added". Restore the hovered tile AND all tiles after
      // it to their original positions.
      for (int i = snakeDragPath.length - 1; i >= existingIndex; i--) {
        Tile pathTile = snakeDragPath[i];
        Tile originalTile = snakeDragOriginalTiles.firstWhere((t) => t.id == pathTile.id);
        int boardIdx = tiles.indexWhere((t) => t.id == pathTile.id);
        if (boardIdx >= 0) {
          tiles[boardIdx] = tiles[boardIdx].copyWith(row: originalTile.row, col: originalTile.col);
        }
      }
      // Restore dragged tile to where it was before the hovered tile was added.
      // If existingIndex == 1, that means back to origin.
      // Otherwise, back to the original position of path[existingIndex - 1].
      int draggedIdx = tiles.indexWhere((t) => t.id == snakeDragOrigin!.id);
      if (draggedIdx >= 0) {
        if (existingIndex <= 1) {
          Tile originalOrigin = snakeDragOriginalTiles.firstWhere((t) => t.id == snakeDragOrigin!.id);
          tiles[draggedIdx] = tiles[draggedIdx].copyWith(row: originalOrigin.row, col: originalOrigin.col);
        } else {
          Tile prevTile = snakeDragPath[existingIndex - 1];
          Tile prevOriginal = snakeDragOriginalTiles.firstWhere((t) => t.id == prevTile.id);
          tiles[draggedIdx] = tiles[draggedIdx].copyWith(row: prevOriginal.row, col: prevOriginal.col);
        }
      }
      // Keep at least the origin in the path
      snakeDragPath = existingIndex > 0
          ? snakeDragPath.sublist(0, existingIndex)
          : [snakeDragPath[0]];
    } else {
      // Extend path: hoveredTile shifts to dragged tile's current position,
      // dragged tile takes hoveredTile's former position
      int draggedIdx = tiles.indexWhere((t) => t.id == snakeDragOrigin!.id);
      int hoveredIdx = tiles.indexWhere((t) => t.id == hoveredTile.id);

      if (draggedIdx < 0 || hoveredIdx < 0) return;

      int hoveredRow = tiles[hoveredIdx].row;
      int hoveredCol = tiles[hoveredIdx].col;
      int dragRow = tiles[draggedIdx].row;
      int dragCol = tiles[draggedIdx].col;

      // Hovered tile moves to where dragged tile is
      tiles[hoveredIdx] = tiles[hoveredIdx].copyWith(row: dragRow, col: dragCol);
      // Dragged tile moves to where hovered tile was
      tiles[draggedIdx] = tiles[draggedIdx].copyWith(row: hoveredRow, col: hoveredCol);

      snakeDragPath.add(tiles[hoveredIdx]);
    }

    notifyListeners();
  }

  /// Mode 5: End snake drag
  Future<void> endSnakeDrag() async {
    if (snakeDragOrigin == null) return;

    // Check if full backtrack (all tiles at original positions)
    bool fullBacktrack = snakeDragPath.length <= 1;

    if (!fullBacktrack) {
      // Also check if the dragged tile ended up back at its origin
      Tile originalOrigin = snakeDragOriginalTiles.firstWhere((t) => t.id == snakeDragOrigin!.id);
      Tile currentOrigin = tiles.firstWhere((t) => t.id == snakeDragOrigin!.id);
      if (currentOrigin.row == originalOrigin.row && currentOrigin.col == originalOrigin.col) {
        fullBacktrack = true;
      }
    }

    if (fullBacktrack) {
      // No move counted, restore everything
      _restoreSnakeDragOriginals();
      _clearSnakeDragState();
      notifyListeners();
      return;
    }

    // Collect all tiles that moved
    List<Tile> movedTiles = [];
    for (var tile in tiles) {
      Tile original = snakeDragOriginalTiles.firstWhere((t) => t.id == tile.id);
      if (tile.row != original.row || tile.col != original.col) {
        movedTiles.add(tile);
      }
    }

    isMatching = true;
    sessionMoves++;
    notifyListeners();

    List<List<Tile>> matches = findMatches(activeTiles: movedTiles);

    if (matches.isEmpty) {
      // Restore all tiles, apply penalty
      _restoreSnakeDragOriginals();
      if (totalScore > 0) totalScore -= 1;
      lastMoveScore = -1;
      sessionUserScore -= 1;
      isMatching = false;
      _clearSnakeDragState();
      notifyListeners();
    } else {
      int moveScore = calculateMatchesScore(matches);
      lastMoveScore = moveScore;
      sessionUserScore += moveScore;

      // Guard celebration with calculatesOptimum
      if (currentMode.calculatesOptimum && moveScore >= optimumScore) {
        showOptimumCelebration = true;
      }

      _clearSnakeDragState();

      if (isSnapshotMode) {
        isPausedForSnapshot = true;
        currentMatches = matches;
        userMatchTiles = [];
        for (var match in matches) {
          userMatchTiles.addAll(match);
        }
        notifyListeners();
      } else {
        await processMatches(matches);
      }
    }
  }

  void _restoreSnakeDragOriginals() {
    for (int i = 0; i < tiles.length; i++) {
      Tile original = snakeDragOriginalTiles.firstWhere((t) => t.id == tiles[i].id);
      tiles[i] = tiles[i].copyWith(row: original.row, col: original.col);
    }
  }

  void _clearSnakeDragState() {
    snakeDragPath = [];
    snakeDragOrigin = null;
    snakeDragOriginalTiles = [];
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

    Set<Tile> toRemove = {};
    for (var match in matches) {
      toRemove.addAll(match);
    }

    Set<String> toRemoveIds = toRemove.map((t) => t.id).toSet();
    List<Point<int>> refillPositions = toRemove.map((t) => Point(t.row, t.col)).toList();

    tiles.removeWhere((t) => toRemoveIds.contains(t.id));
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));

    if (currentMode.usesGravity) {
      _applyGravityDrop();
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      _fillEmptyPositions();
    } else if (currentMode.highScoreGeneration) {
      _generateTilesWithHighScoreConstraint(refillPositions);
    } else {
      for (var pos in refillPositions) {
        tiles.add(_generateRandomTile(pos.x, pos.y));
      }
    }

    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));

    // If we are celebrating an optimum move, wait a bit longer so user can see it
    if (showOptimumCelebration) {
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    isMatching = false;
    showOptimumCelebration = false;
    calculateOptimumScore();
    notifyListeners();
  }

  /// Mode 3 phase 1: Drop existing tiles down within their columns
  void _applyGravityDrop() {
    Set<String> occupied = {};
    for (var tile in tiles) {
      occupied.add('${tile.row},${tile.col}');
    }

    for (int c = 0; c < cols; c++) {
      for (int r = rows - 1; r >= 0; r--) {
        if (!occupied.contains('$r,$c')) {
          for (int above = r - 1; above >= 0; above--) {
            if (occupied.contains('$above,$c')) {
              int idx = tiles.indexWhere((t) => t.row == above && t.col == c);
              if (idx >= 0) {
                occupied.remove('$above,$c');
                occupied.add('$r,$c');
                tiles[idx] = tiles[idx].copyWith(row: r, col: c);
                break;
              }
            }
          }
        }
      }
    }
  }

  /// Mode 3 phase 2: Fill remaining empty positions with new random tiles
  void _fillEmptyPositions() {
    Set<String> occupied = {};
    for (var tile in tiles) {
      occupied.add('${tile.row},${tile.col}');
    }

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!occupied.contains('$r,$c')) {
          tiles.add(_generateRandomTile(r, c));
        }
      }
    }
  }

  void calculateOptimumScore() {
    if (!currentMode.calculatesOptimum) {
      optimumScore = 0;
      optimumMatchTiles = [];
      optimumSwapTiles = [];
      return;
    }

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

    List<List<Tile>> matches = findMatches(customTiles: tempTiles, activeTiles: [newT1, newT2]);
    if (matches.isEmpty) return (score: 0, matchedTiles: [], swapTiles: []);

    List<Tile> allMatchTiles = [];
    for (var m in matches) {
      allMatchTiles.addAll(m);
    }

    return (
      score: calculateMatchesScore(matches),
      matchedTiles: allMatchTiles,
      swapTiles: [t1, t2]
    );
  }
}
