import 'package:flutter/material.dart';
import '../../domain/logic/game_state.dart';
import '../widgets/board_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameState _gameState = GameState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _gameState,
          builder: (context, child) {
            return Stack(
              children: [
                Column(
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: BoardWidget(gameState: _gameState),
                      ),
                    ),
                    _buildBottomBar(),
                  ],
                ),
                if (_gameState.showOptimumCelebration)
                  GestureDetector(
                    onTap: () {
                      _gameState.showOptimumCelebration = false;
                      _gameState.notifyListeners();
                    },
                    child: _buildCelebrationOverlay(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
Widget _buildTopBar() {
  return Container(
    padding: const EdgeInsets.all(16.0),
    decoration: const BoxDecoration(
      color: Colors.green,
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => _gameState.toggleHint(),
          child: _buildInfoColumn('MOVE CREDITS', 'B', isIcon: true),
        ),
        Column(
            children: [
              Text(
                _gameState.totalScore.toString().padLeft(4, '0'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _gameState.lastMoveScore > 0 ? '+${_gameState.lastMoveScore}' : '',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),
          _buildInfoColumn('OPTIMUM SCORE', _gameState.optimumScore.toString()),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {bool isIcon = false}) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30, width: 2),
            color: Colors.black26,
          ),
          child: Center(
            child: isIcon
                ? const Icon(Icons.monetization_on, color: Colors.orange, size: 30)
                : Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white70, size: 40),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              _gameState.isSnapshotMode ? Icons.camera : Icons.camera_outlined,
              color: _gameState.isSnapshotMode ? Colors.blueAccent : Colors.white70,
              size: 40,
            ),
            onPressed: () => _gameState.toggleSnapshotMode(),
          ),
          IconButton(
            icon: Icon(
              Icons.play_arrow,
              color: _gameState.isPausedForSnapshot ? Colors.greenAccent : Colors.white24,
              size: 40,
            ),
            onPressed: _gameState.isPausedForSnapshot ? () => _gameState.continueFromSnapshot() : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 40),
            onPressed: () => _gameState.initializeBoard(),
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrationOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.yellow, size: 100),
            const Text(
              'OPTIMUM MOVE!',
              style: TextStyle(
                color: Colors.yellow,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '+${_gameState.optimumScore} POINTS',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}
