import 'package:flutter/material.dart';
import 'presentation/screens/game_screen.dart';

void main() {
  runApp(const Match3PlusApp());
}

class Match3PlusApp extends StatelessWidget {
  const Match3PlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Match-3 Plus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
