import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/logic/game_state.dart';
import '../../domain/models/game_mode.dart';
import '../widgets/board_widget.dart';
import '../widgets/mode_selection_dialog.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameState _gameState = GameState();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'MOVES: ${_gameState.sessionMoves}  ',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                'RATE: ${(_gameState.moveQuality * 100).toStringAsFixed(0)}%  ',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'TIME: ${_gameState.sessionDurationString}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModeColumn(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _gameState.totalScore.toString().padLeft(4, '0'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LAST: ${_gameState.lastMoveScore > 0 ? "+" : ""}${_gameState.lastMoveScore}  ',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '(OPTIMUM: ${_gameState.previousOptimumScore})',
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_gameState.currentMode.calculatesOptimum)
                GestureDetector(
                  onTap: () => _gameState.toggleHint(),
                  child: _buildInfoColumn(
                    'OPTIMUM',
                    _gameState.optimumScore.toString(),
                  ),
                )
              else if (_gameState.hasDragPreview)
                _buildInfoColumn(
                  'OPTIMUM IF',
                  _gameState.dragPreviewOptimum.toString(),
                )
              else
                _buildInfoColumn('OPTIMUM', '?'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {bool isIcon = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
        const SizedBox(height: 2),
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
                ? const Icon(
                    Icons.monetization_on,
                    color: Colors.orange,
                    size: 30,
                  )
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
            onPressed: _showModeSelectionDialog,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white10, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _gameState.isSnapshotMode ? Icons.camera : Icons.camera_outlined,
                    color: _gameState.isSnapshotMode
                        ? Colors.blueAccent
                        : Colors.white70,
                    size: 40,
                  ),
                  onPressed: () => _gameState.toggleSnapshotMode(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.play_arrow,
                    color: _gameState.isPausedForSnapshot
                        ? Colors.greenAccent
                        : Colors.white24,
                    size: 40,
                  ),
                  onPressed: _gameState.isPausedForSnapshot
                      ? () => _gameState.continueFromSnapshot()
                      : null,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white70,
                  size: 40,
                ),
                onPressed: _showRefreshConfirmation,
              ),
              if (_gameState.currentMode.calculatesOptimum)
                Text(
                  '-${_gameState.optimumScore}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            _gameState.currentMode.name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30, width: 2),
            color: Colors.black26,
          ),
          child: Center(
            child: Icon(
              _gameState.currentMode.icon,
              color: Colors.orange,
              size: 30,
            ),
          ),
        ),
      ],
    );
  }

  void _showModeSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => ModeSelectionDialog(gameState: _gameState),
    );
  }

  void _showRefreshConfirmation() {
    _gameState.isDialogOpen = true;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white10, width: 1),
        ),
        title: const Text(
          'REDRAW BOARD?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _gameState.currentMode.calculatesOptimum
                  ? 'A new board will be generated, but your total score will be decreased by the current optimum.'
                  : 'A new board will be generated.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            if (_gameState.currentMode.calculatesOptimum) ...[
              const SizedBox(height: 20),
              Text(
                '-${_gameState.optimumScore}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _gameState.initializeBoard(
                deductScore: true,
                resetSession: false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'CONFIRM',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).then((_) {
      _gameState.isDialogOpen = false;
    });
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
