import 'package:flutter/material.dart';
import '../../domain/logic/game_state.dart';
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

  void _handleTileTap(Tile tile) {
    if (widget.gameState.isMatching || widget.gameState.isPausedForSnapshot) return;

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
        widget.gameState.swapTiles(_selectedTile!, tile);
        setState(() {
          _selectedTile = null;
        });
      }
    }
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

        final double boardWidth = cols * coinSize + (cols - 1) * spacing + padding * 2;
        final double boardHeight = rows * coinSize + (rows - 1) * spacing + padding * 2;

        final List<Tile> sortedTiles = List.from(widget.gameState.tiles);
        
        Set<String> userMatchIds = widget.gameState.userMatchTiles.map((t) => t.id).toSet();
        Set<String> optimumMatchIds = widget.gameState.optimumMatchTiles.map((t) => t.id).toSet();
        Set<String> optimumSwapIds = widget.gameState.optimumSwapTiles.map((t) => t.id).toSet();

        sortedTiles.sort((a, b) {
          bool aSpecial = a.id == _selectedTile?.id || 
                          userMatchIds.contains(a.id) || 
                          (widget.gameState.isPausedForSnapshot && optimumMatchIds.contains(a.id)) ||
                          (widget.gameState.showHint && (optimumMatchIds.contains(a.id) || optimumSwapIds.contains(a.id)));
          
          bool bSpecial = b.id == _selectedTile?.id || 
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
                  bool isUserMatch = userMatchTilesIntersect(tile);
                  bool isOptimumMatch = optimumMatchTilesIntersect(tile);
                  bool isHintSwap = optimumSwapTilesIntersect(tile) && widget.gameState.showHint;
                  bool showOptimumBorder = (isOptimumMatch && (widget.gameState.isPausedForSnapshot || widget.gameState.showHint));
                  
                  return AnimatedPositioned(
                    key: ValueKey(tile.id),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: tile.col * (coinSize + spacing),
                    top: tile.row * (coinSize + spacing),
                    width: coinSize,
                    height: coinSize,
                    child: AnimatedScale(
                      scale: isUserMatch ? 1.2 : (isSelected ? 1.1 : 1.0),
                      duration: const Duration(milliseconds: 200),
                      child: TileWidget(
                        tile: tile,
                        size: coinSize,
                        onTap: () => _handleTileTap(tile),
                        isOptimum: showOptimumBorder && !isHintSwap,
                        isHintSwap: isHintSwap,
                      ),
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
