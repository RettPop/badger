import 'package:flutter/material.dart';
import '../../domain/logic/game_state.dart';
import '../../domain/models/game_mode.dart';

class ModeSelectionDialog extends StatelessWidget {
  final GameState gameState;

  const ModeSelectionDialog({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2D2D2D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Colors.white10, width: 1),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'SELECT MODE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          GameModeType.convenient,
          GameModeType.arcade,
          GameModeType.highScores,
          GameModeType.dropDown,
          GameModeType.simpleDrag,
          GameModeType.snakeDrag,
        ].map((mode) {
          final bool isActive = mode == gameState.currentMode;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  gameState.setMode(mode);
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: isActive
                        ? Border.all(color: Colors.green, width: 2)
                        : Border.all(color: Colors.white10, width: 1),
                    color: isActive
                        ? Colors.green.withOpacity(0.15)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Icon(
                          mode.icon,
                          color: isActive ? Colors.green : Colors.white70,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mode.name,
                          style: TextStyle(
                            color: isActive ? Colors.green : Colors.white,
                            fontSize: 16,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isActive)
                        const Icon(Icons.check, color: Colors.green, size: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
