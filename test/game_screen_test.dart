import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smatcher/domain/logic/game_state.dart';
import 'package:smatcher/domain/models/game_mode.dart';
import 'package:smatcher/presentation/screens/game_screen.dart';

void main() {
  group('GameScreen — top bar and mode display', () {
    testWidgets('top bar shows mode name and icon for convenient mode',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen()),
      );
      await tester.pumpAndSettle();

      // In convenient mode, the top bar should show the mode name
      expect(find.text('Convenient'), findsOneWidget);

      // The spa icon (convenient mode icon) should be present
      expect(find.byIcon(Icons.spa), findsOneWidget);
    });

    testWidgets('top bar hides OPTIMUM and RATIO in simpleDrag mode',
        (tester) async {
      // We need to access the GameState to switch modes.
      // GameScreen creates its own GameState internally, so we pump it
      // and then interact via the UI (home button -> mode dialog).
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen()),
      );
      await tester.pumpAndSettle();

      // Tap the home button to open mode selection dialog
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      // Select Simple Drag mode
      await tester.tap(find.text('Simple Drag'));
      await tester.pumpAndSettle();

      // OPTIMUM should show "?" in drag modes (not a number)
      expect(find.text('?'), findsOneWidget);

      // RATE should still be visible
      expect(find.textContaining('RATE'), findsOneWidget);
    });

    testWidgets('top bar shows OPTIMUM and RATIO in convenient mode',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen()),
      );
      await tester.pumpAndSettle();

      // In convenient mode, OPTIMUM label should be visible
      expect(find.textContaining('OPTIMUM'), findsOneWidget);

      // RATE stat should be visible
      expect(find.textContaining('RATE'), findsOneWidget);
    });

    testWidgets('home button opens mode selection dialog', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen()),
      );
      await tester.pumpAndSettle();

      // Tap the home button
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      // The mode selection dialog should appear with all mode names
      expect(find.text('Convenient'), findsWidgets);
      expect(find.text('High Scores (50+)'), findsOneWidget);
      expect(find.text('Drop Down'), findsOneWidget);
      expect(find.text('Simple Drag'), findsOneWidget);
      expect(find.text('Snake Drag'), findsOneWidget);
      expect(find.text('Arcade'), findsOneWidget);
    });

    testWidgets('refresh dialog hides penalty in non-optimum modes',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen()),
      );
      await tester.pumpAndSettle();

      // Switch to Simple Drag mode (non-optimum)
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simple Drag'));
      await tester.pumpAndSettle();

      // Tap the refresh button to open the confirmation dialog
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      // In non-optimum modes, the refresh dialog should not show penalty amount.
      // Check that no text with penalty format (minus sign + digits) appears in dialog.
      final penaltyFinder = find.textContaining(RegExp(r'^-\d+$'));
      expect(penaltyFinder, findsNothing);
    });
  });
}
