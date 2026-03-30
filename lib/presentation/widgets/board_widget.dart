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
    if (widget.gameState.isMatching) return;

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

        // Distance between coins is 20% of coin size
        // TotalWidth = cols * S + (cols - 1) * 0.2 * S
        final double widthBasedSize = constraints.maxWidth / (cols + (cols - 1) * 0.2 + 0.4); 
        final double heightBasedSize = constraints.maxHeight / (rows + (rows - 1) * 0.2 + 0.4);

        final double coinSize = (widthBasedSize < heightBasedSize ? widthBasedSize : heightBasedSize);
        final double spacing = coinSize * 0.2;
        final double padding = coinSize * 0.2; // Border around the grid

        final double boardWidth = cols * coinSize + (cols - 1) * spacing + padding * 2;
        final double boardHeight = rows * coinSize + (rows - 1) * spacing + padding * 2;

        final List<Tile> sortedTiles = List.from(widget.gameState.tiles);
        sortedTiles.sort((a, b) {
          // Selected tile always on top
          if (a.id == _selectedTile?.id) return 1;
          if (b.id == _selectedTile?.id) return -1;
          
          // To make badges (top-right) visible, we draw from top to bottom, 
          // and from right to left? No, badges are at top-right.
          // If we draw (0,1) then (0,0), (0,0)'s badge is on top of (0,1). Correct.
          // If we draw (0,0) then (1,0), (1,0)'s badge is on top of (0,0). Correct.
          // So: Row Ascending, Col Descending.
          if (a.row != b.row) return a.row.compareTo(b.row);
          return b.col.compareTo(a.col);
        });

        return Center(
          child: Container(
            width: boardWidth,
            height: boardHeight,
            decoration: BoxDecoration(
              color: Colors.black, // Dark field
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
                  return AnimatedPositioned(
                    key: ValueKey(tile.id),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: tile.col * (coinSize + spacing),
                    top: tile.row * (coinSize + spacing),
                    width: coinSize,
                    height: coinSize,
                    child: Transform.scale(
                      scale: isSelected ? 1.1 : 1.0,
                      child: TileWidget(
                        tile: tile,
                        size: coinSize,
                        onTap: () => _handleTileTap(tile),
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
}
