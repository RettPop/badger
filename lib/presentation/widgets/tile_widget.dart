import 'package:flutter/material.dart';
import '../../domain/models/tile.dart';

class TileWidget extends StatelessWidget {
  final Tile tile;
  final double size;
  final bool isOptimum;
  final bool isHintSwap;

  const TileWidget({
    super.key,
    required this.tile,
    required this.size,
    this.isOptimum = false,
    this.isHintSwap = false,
  });

  @override
  Widget build(BuildContext context) {
    final double badgeDiameter = size * 0.3;
    final double letterSize = size * 0.5;

    Color? borderColor;
    if (isHintSwap) {
      borderColor = Colors.red;
    } else if (isOptimum) {
      borderColor = Colors.blue;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The Coin Square
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: tile.color,
                borderRadius: BorderRadius.circular(16.0),
                border: borderColor != null
                  ? Border.all(color: borderColor, width: 8)
                  : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(80),
                    blurRadius: 6,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  tile.letter,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: letterSize,
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The Badge
          Positioned(
            top: -badgeDiameter / 2,
            right: -badgeDiameter / 2,
            child: Container(
              width: badgeDiameter,
              height: badgeDiameter,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 3,
                    offset: Offset(1, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${tile.value}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: badgeDiameter * 0.6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
