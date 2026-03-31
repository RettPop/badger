import 'package:flutter/material.dart';
import 'presentation/screens/game_screen.dart';

void main() {
  runApp(const BadgerApp());
}

class BadgerApp extends StatelessWidget {
  const BadgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Badger',
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
