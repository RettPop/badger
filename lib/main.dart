import 'package:flutter/material.dart';
import 'presentation/screens/game_screen.dart';

void main() {
  runApp(const SMatcherApp());
}

class SMatcherApp extends StatelessWidget {
  const SMatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMatcher',
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
