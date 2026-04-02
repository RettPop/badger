import 'package:flutter/material.dart';
import '../../domain/logic/game_state.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/models/tile.dart';
import 'tile_widget.dart';

class BoardWidget extends StatefulWidget {
  final GameState gameState;

  const BoardWidget({super.key, required this.gameState});

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  Tile? _selectedTile;

  // Drag state
  Tile? _draggedTile;
  Offset? _dragOffset; // current finger position relative to the board stack
  Tile? _dragTarget;
  Tile? _lastSnakeHoveredTile;

  // Layout cache (set during build for use in gesture handlers)
  double _coinSize = 0;
  double _spacing = 0;
  double _padding = 0;
  GlobalKey _boardKey = GlobalKey();

  /// Converts a local position within the board's Stack to the Tile at that
  /// grid cell, or null if the position is outside the grid.
  Tile? _tileAtPosition(Offset localPosition) {
    final coinSize = _coinSize;
    final spacing = _spacing;
    final padding = _padding;

    // Adjust for padding
    final double x = localPosition.dx - padding;
    final double y = localPosition.dy - padding;

    if (x < 0 || y < 0) return null;

    final double cellSize = coinSize + spacing;
    final int col = (x / cellSize).floor();
    final int row = (y / cellSize).floor();

    if (col < 0 || col >= widget.gameState.cols) return null;
    if (row < 0 || row >= widget.gameState.rows) return null;

    // Check that the position is within the tile area (not in the spacing gap)
    final double xInCell = x - col * cellSize;
    final double yInCell = y - row * cellSize;
    if (xInCell > coinSize || yInCell > coinSize) return null;

    // Find the tile at this grid position
    try {
      return widget.gameState.tiles.firstWhere(
        (t) => t.row == row && t.col == col,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isAdjacent(Tile a, Tile b) {
    return (a.row == b.row && (a.col - b.col).abs() == 1) ||
           (a.col == b.col && (a.row - b.row).abs() == 1);
  }

  void _handleTileTap(Tile tile) {
    if (widget.gameState.isMatching || widget.gameState.isPausedForSnapshot) return;

    // Disable tap in snake drag mode
    if (widget.gameState.currentMode.isSnakeDrag) return;

    if (_selectedTile == null) {
      setState(() {
        _selectedTile = tile;
      });
    } else {
      if (_selectedTile == tile) {
        setState(() {
          _selectedTile = null;
        });
      } else {
        // Tap-to-select always uses adjacent swap (swapTiles)
        widget.gameState.swapTiles(_selectedTile!, tile);
        setState(() {
          _selectedTile = null;
        });
      }
    }
  }

  void _handlePanStart(Tile tile, DragStartDetails details) {
    if (widget.gameState.isMatching || widget.gameState.isPausedForSnapshot) return;

    setState(() {
      _selectedTile = null; // Clear tap selection when drag starts
      _draggedTile = tile;
      _dragOffset = details.localPosition;
      _dragTarget = null;
      _lastSnakeHoveredTile = null;
    });

    // For snake drag mode, notify GameState
    if (widget.gameState.currentMode.isSnakeDrag) {
      widget.gameState.startSnakeDrag(tile);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, double boardWidth, double boardHeight) {
    if (_draggedTile == null) return;

    setState(() {
      _dragOffset = (_dragOffset ?? Offset.zero) + details.delta;
    });

    // Convert the drag offset to board-local coordinates
    // _dragOffset is relative to the tile's original position in the board
    final tile = _draggedTile!;
    final tileOriginX = _padding + tile.col * (_coinSize + _spacing);
    final tileOriginY = _padding + tile.row * (_coinSize + _spacing);
    final fingerBoardPos = Offset(
      tileOriginX + (_dragOffset?.dx ?? 0),
      tileOriginY + (_dragOffset?.dy ?? 0),
    );

    final hoveredTile = _tileAtPosition(fingerBoardPos);

    if (widget.gameState.currentMode.isSnakeDrag) {
      // Snake drag: continuously update path
      if (hoveredTile != null && hoveredTile.id != (_lastSnakeHoveredTile?.id ?? _draggedTile?.id)) {
        _lastSnakeHoveredTile = hoveredTile;
        widget.gameState.updateSnakeDrag(hoveredTile);
      }
    } else {
      // Regular drag: just track the target
      setState(() {
        _dragTarget = hoveredTile;
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_draggedTile == null) return;

    final source = _draggedTile!;

    if (widget.gameState.currentMode.isSnakeDrag) {
      // Snake drag: end the drag in GameState
      widget.gameState.endSnakeDrag();
    } else if (_dragTarget != null && _dragTarget!.id != source.id) {
      final target = _dragTarget!;

      if (widget.gameState.currentMode.allowsDragToAny) {
        // Mode 4 (Simple Drag): any-position swap
        widget.gameState.swapTilesAny(source, target);
      } else {
        // Modes 1, 2, 3, 6: adjacent-only drag
        if (_isAdjacent(source, target)) {
          widget.gameState.swapTiles(source, target);
        }
      }
    }

    setState(() {
      _draggedTile = null;
      _dragOffset = null;
      _dragTarget = null;
      _lastSnakeHoveredTile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int cols = widget.gameState.cols;
        final int rows = widget.gameState.rows;

        final double widthBasedSize = constraints.maxWidth / (cols + (cols - 1) * 0.2 + 0.4);
        final double heightBasedSize = constraints.maxHeight / (rows + (rows - 1) * 0.2 + 0.4);

        final double coinSize = (widthBasedSize < heightBasedSize ? widthBasedSize : heightBasedSize);
        final double spacing = coinSize * 0.2;
        final double padding = coinSize * 0.2;

        // Cache layout values for gesture handlers
        _coinSize = coinSize;
        _spacing = spacing;
        _padding = padding;

        final double boardWidth = cols * coinSize + (cols - 1) * spacing + padding * 2;
        final double boardHeight = rows * coinSize + (rows - 1) * spacing + padding * 2;

        final List<Tile> sortedTiles = List.from(widget.gameState.tiles);

        Set<String> userMatchIds = widget.gameState.userMatchTiles.map((t) => t.id).toSet();
        Set<String> optimumMatchIds = widget.gameState.optimumMatchTiles.map((t) => t.id).toSet();
        Set<String> optimumSwapIds = widget.gameState.optimumSwapTiles.map((t) => t.id).toSet();

        sortedTiles.sort((a, b) {
          bool aSpecial = a.id == _selectedTile?.id ||
                          a.id == _draggedTile?.id ||
                          userMatchIds.contains(a.id) ||
                          (widget.gameState.isPausedForSnapshot && optimumMatchIds.contains(a.id)) ||
                          (widget.gameState.showHint && (optimumMatchIds.contains(a.id) || optimumSwapIds.contains(a.id)));

          bool bSpecial = b.id == _selectedTile?.id ||
                          b.id == _draggedTile?.id ||
                          userMatchIds.contains(b.id) ||
                          (widget.gameState.isPausedForSnapshot && optimumMatchIds.contains(b.id)) ||
                          (widget.gameState.showHint && (optimumMatchIds.contains(b.id) || optimumSwapIds.contains(b.id)));

          if (aSpecial && !bSpecial) return 1;
          if (!aSpecial && bSpecial) return -1;

          if (a.row != b.row) return a.row.compareTo(b.row);
          return b.col.compareTo(a.col);
        });

        return Center(
          child: Container(
            key: _boardKey,
            width: boardWidth,
            height: boardHeight,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(150),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Stack(
                clipBehavior: Clip.none,
                children: sortedTiles.map((tile) {
                  bool isSelected = _selectedTile?.id == tile.id;
                  bool isDragged = _draggedTile?.id == tile.id;
                  bool isUserMatch = userMatchTilesIntersect(tile);
                  bool isOptimumMatch = optimumMatchTilesIntersect(tile);
                  bool isHintSwap = optimumSwapTilesIntersect(tile) && widget.gameState.showHint;
                  bool showOptimumBorder = (isOptimumMatch && (widget.gameState.isPausedForSnapshot || widget.gameState.showHint));

                  // Calculate position - if dragged, follow finger
                  double left = tile.col * (coinSize + spacing);
                  double top = tile.row * (coinSize + spacing);

                  if (isDragged && _dragOffset != null) {
                    // Position the tile at the finger position
                    left += _dragOffset!.dx - coinSize / 2;
                    top += _dragOffset!.dy - coinSize / 2;
                  }

                  final tileWidget = TileWidget(
                    tile: tile,
                    size: coinSize,
                    isOptimum: showOptimumBorder && !isHintSwap,
                    isHintSwap: isHintSwap,
                  );

                  final wrappedTile = GestureDetector(
                    onTap: () => _handleTileTap(tile),
                    onPanStart: (details) => _handlePanStart(tile, details),
                    onPanUpdate: (details) => _handlePanUpdate(details, boardWidth, boardHeight),
                    onPanEnd: _handlePanEnd,
                    child: tileWidget,
                  );

                  if (isDragged && _dragOffset != null) {
                    // Dragged tile: use Positioned (no animation) to follow finger
                    return Positioned(
                      key: ValueKey(tile.id),
                      left: left,
                      top: top,
                      width: coinSize,
                      height: coinSize,
                      child: AnimatedScale(
                        scale: 1.15,
                        duration: const Duration(milliseconds: 100),
                        child: wrappedTile,
                      ),
                    );
                  }

                  return AnimatedPositioned(
                    key: ValueKey(tile.id),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: left,
                    top: top,
                    width: coinSize,
                    height: coinSize,
                    child: AnimatedScale(
                      scale: isUserMatch ? 1.2 : (isSelected ? 1.1 : 1.0),
                      duration: const Duration(milliseconds: 200),
                      child: wrappedTile,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  bool userMatchTilesIntersect(Tile tile) {
    return widget.gameState.userMatchTiles.any((t) => t.id == tile.id);
  }

  bool optimumMatchTilesIntersect(Tile tile) {
    return widget.gameState.optimumMatchTiles.any((t) => t.id == tile.id);
  }

  bool optimumSwapTilesIntersect(Tile tile) {
    return widget.gameState.optimumSwapTiles.any((t) => t.id == tile.id);
  }
}
