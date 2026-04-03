import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'presentation/screens/game_screen.dart';

String appVersion = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final info = await PackageInfo.fromPlatform();
  appVersion = '${info.version}+${info.buildNumber}';
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
