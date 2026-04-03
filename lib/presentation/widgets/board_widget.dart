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
  Offset _dragDelta = Offset.zero;
  Tile? _dragTarget;
  Tile? _lastSnakeHoveredTile;
  bool _isDragging = false;
  Offset? _pointerDownPos;
  Tile? _pointerDownTile;
  // Original grid position of the dragged tile (for snake drag, stays fixed)
  int _dragOriginRow = 0;
  int _dragOriginCol = 0;

  // Layout cache
  double _coinSize = 0;
  double _spacing = 0;
  double _padding = 0;

  static const double _dragThreshold = 8.0; // pixels before we consider it a drag

  Tile? _tileAtPosition(Offset localPosition) {
    final double x = localPosition.dx - _padding;
    final double y = localPosition.dy - _padding;

    if (x < 0 || y < 0) return null;

    final double cellSize = _coinSize + _spacing;
    final int col = (x / cellSize).floor();
    final int row = (y / cellSize).floor();

    if (col < 0 || col >= widget.gameState.cols) return null;
    if (row < 0 || row >= widget.gameState.rows) return null;

    final double xInCell = x - col * cellSize;
    final double yInCell = y - row * cellSize;
    if (xInCell > _coinSize || yInCell > _coinSize) return null;

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

  void _handleTap(Tile tile) {
    if (widget.gameState.isMatching || widget.gameState.isPausedForSnapshot) return;
    if (widget.gameState.currentMode.isSnakeDrag) return;

    if (_selectedTile == null) {
      setState(() => _selectedTile = tile);
    } else {
      if (_selectedTile!.id == tile.id) {
        setState(() => _selectedTile = null);
      } else {
        widget.gameState.swapTiles(_selectedTile!, tile);
        setState(() => _selectedTile = null);
      }
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.gameState.isMatching || widget.gameState.isPausedForSnapshot) return;

    final tile = _tileAtPosition(event.localPosition);
    if (tile == null) return;

    _pointerDownPos = event.localPosition;
    _pointerDownTile = tile;
    _isDragging = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointerDownTile == null) return;

    if (!_isDragging) {
      // Check if we've moved enough to start a drag
      final delta = event.localPosition - _pointerDownPos!;
      if (delta.distance < _dragThreshold) return;

      // Start dragging
      _isDragging = true;
      _dragOriginRow = _pointerDownTile!.row;
      _dragOriginCol = _pointerDownTile!.col;
      setState(() {
        _selectedTile = null;
        _draggedTile = _pointerDownTile;
        _dragDelta = delta;
        _dragTarget = null;
        _lastSnakeHoveredTile = null;
      });

      if (widget.gameState.currentMode.isSnakeDrag) {
        widget.gameState.startSnakeDrag(_pointerDownTile!);
      }
    } else {
      // Continue dragging
      final delta = event.localPosition - _pointerDownPos!;
      setState(() {
        _dragDelta = delta;
      });
    }

    // Hit-test for hover target — use origin position (not model, which changes in snake drag)
    final tile = _draggedTile!;
    final cellSize = _coinSize + _spacing;
    final tileCenterX = _padding + _dragOriginCol * cellSize + _coinSize / 2 + _dragDelta.dx;
    final tileCenterY = _padding + _dragOriginRow * cellSize + _coinSize / 2 + _dragDelta.dy;
    final hoveredTile = _tileAtPosition(Offset(tileCenterX, tileCenterY));

    if (widget.gameState.currentMode.isSnakeDrag) {
      // For snake drag, determine which grid cell the finger is over
      // and let GameState handle adjacency checks
      final x = tileCenterX - _padding;
      final y = tileCenterY - _padding;
      if (x >= 0 && y >= 0) {
        final col = (x / cellSize).floor();
        final row = (y / cellSize).floor();
        if (col >= 0 && col < widget.gameState.cols &&
            row >= 0 && row < widget.gameState.rows) {
          // Only call if we've entered a new cell
          final cellKey = '$row,$col';
          final lastKey = _lastSnakeHoveredTile != null
              ? '${_lastSnakeHoveredTile!.row},${_lastSnakeHoveredTile!.col}'
              : '${_dragOriginRow},${_dragOriginCol}';
          if (cellKey != lastKey) {
            _lastSnakeHoveredTile = Tile(id: 'hover', row: row, col: col,
                color: const Color(0), letter: '', value: 0);
            widget.gameState.updateSnakeDragAt(row, col);
            // Restart preview timer for the new board state
            widget.gameState.startDragPreviewOptimumForCurrentBoard();
          }
        }
      }
    } else {
      Tile? newTarget;
      if (hoveredTile != null && hoveredTile.id != tile.id) {
        if (!widget.gameState.currentMode.allowsDragToAny) {
          newTarget = _isAdjacent(tile, hoveredTile) ? hoveredTile : null;
        } else {
          newTarget = hoveredTile;
        }
      }

      // Start/cancel drag preview optimum for modes without auto-optimum
      if (!widget.gameState.currentMode.calculatesOptimum) {
        if (newTarget != null && newTarget.id != (_dragTarget?.id)) {
          widget.gameState.startDragPreviewOptimum(tile, newTarget);
        } else if (newTarget == null && _dragTarget != null) {
          widget.gameState.cancelDragPreviewOptimum();
        }
      }

      setState(() {
        _dragTarget = newTarget;
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointerDownTile == null) return;

    if (!_isDragging) {
      // It was a tap, not a drag
      _handleTap(_pointerDownTile!);
    } else if (_draggedTile != null) {
      final source = _draggedTile!;

      // Don't cancel preview here — swap methods capture it before clearing
      if (widget.gameState.currentMode.isSnakeDrag) {
        widget.gameState.endSnakeDrag();
      } else if (_dragTarget != null && _dragTarget!.id != source.id) {
        final target = _dragTarget!;
        if (widget.gameState.currentMode.allowsDragToAny) {
          widget.gameState.swapTilesAny(source, target);
        } else if (_isAdjacent(source, target)) {
          widget.gameState.swapTiles(source, target);
        } else {
          widget.gameState.cancelDragPreviewOptimum();
        }
      } else {
        widget.gameState.cancelDragPreviewOptimum();
      }

      setState(() {
        _draggedTile = null;
        _dragDelta = Offset.zero;
        _dragTarget = null;
        _lastSnakeHoveredTile = null;
      });
    }

    _pointerDownTile = null;
    _pointerDownPos = null;
    _isDragging = false;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_isDragging && _draggedTile != null) {
      if (widget.gameState.currentMode.isSnakeDrag) {
        widget.gameState.endSnakeDrag();
      }
      setState(() {
        _draggedTile = null;
        _dragDelta = Offset.zero;
        _dragTarget = null;
        _lastSnakeHoveredTile = null;
      });
    }
    _pointerDownTile = null;
    _pointerDownPos = null;
    _isDragging = false;
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
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: Container(
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

                    // Preview swap only for non-snake modes
                    bool isDragPreviewTarget = !isDragged &&
                        _draggedTile != null &&
                        _dragTarget != null &&
                        tile.id == _dragTarget!.id &&
                        !widget.gameState.currentMode.isSnakeDrag;

                    double left = tile.col * (coinSize + spacing);
                    double top = tile.row * (coinSize + spacing);

                    if (isDragged) {
                      // Use origin position + delta so the tile doesn't jump
                      // when its model row/col changes (e.g., in snake drag)
                      left = _dragOriginCol * (coinSize + spacing) + _dragDelta.dx;
                      top = _dragOriginRow * (coinSize + spacing) + _dragDelta.dy;
                    } else if (isDragPreviewTarget) {
                      left = _draggedTile!.col * (coinSize + spacing);
                      top = _draggedTile!.row * (coinSize + spacing);
                    }

                    final tileWidget = TileWidget(
                      tile: tile,
                      size: coinSize,
                      isOptimum: showOptimumBorder && !isHintSwap,
                      isHintSwap: isHintSwap,
                    );

                    if (isDragged) {
                      return Positioned(
                        key: ValueKey(tile.id),
                        left: left,
                        top: top,
                        width: coinSize,
                        height: coinSize,
                        child: Transform.scale(
                          scale: 1.15,
                          child: tileWidget,
                        ),
                      );
                    }

                    return AnimatedPositioned(
                      key: ValueKey(tile.id),
                      duration: Duration(milliseconds: isDragPreviewTarget ? 150 : 300),
                      curve: Curves.easeInOut,
                      left: left,
                      top: top,
                      width: coinSize,
                      height: coinSize,
                      child: AnimatedScale(
                        scale: isUserMatch ? 1.2 : (isSelected ? 1.1 : 1.0),
                        duration: const Duration(milliseconds: 200),
                        child: tileWidget,
                      ),
                    );
                  }).toList(),
                ),
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
