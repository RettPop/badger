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

      // OPTIMUM SCORE label should be hidden
      expect(find.textContaining('OPTIMUM SCORE'), findsNothing);

      // QUALITY stat should be hidden
      expect(find.textContaining('QUALITY'), findsNothing);
    });

    testWidgets('top bar shows OPTIMUM and RATIO in convenient mode',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen()),
      );
      await tester.pumpAndSettle();

      // In convenient mode, OPTIMUM SCORE label should be visible
      expect(find.textContaining('OPTIMUM'), findsOneWidget);

      // QUALITY stat should be visible
      expect(find.textContaining('QUALITY'), findsOneWidget);
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
      expect(find.text('High Scores'), findsOneWidget);
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

      // The penalty text (e.g., "-N" or "OPTIMUM" reference) should not appear
      // in non-optimum modes. The dialog should show simplified text.
      expect(find.textContaining('OPTIMUM'), findsNothing);

      // The penalty number format (e.g., "-5") should not appear
      // We check that no Text widget contains a minus sign followed by digits
      // that would indicate a penalty display.
      final penaltyFinder = find.textContaining(RegExp(r'-\d+'));
      // In non-optimum mode, there should be no penalty label in the dialog
      // (the penalty is naturally 0 since optimum is 0, but the UI should
      // hide the penalty section entirely).
      expect(penaltyFinder, findsNothing);
    });
  });
}
