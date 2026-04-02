import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smatcher/domain/logic/game_state.dart';
import 'package:smatcher/domain/models/game_mode.dart';
import 'package:smatcher/presentation/widgets/mode_selection_dialog.dart';

void main() {
  late GameState gameState;

  setUp(() {
    gameState = GameState();
  });

  Widget buildTestApp({Widget? child}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return child ?? const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  /// Helper that opens the ModeSelectionDialog inside a MaterialApp context.
  Widget buildDialogTestApp() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            // Automatically show the dialog after the frame renders.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                builder: (_) => ModeSelectionDialog(gameState: gameState),
              );
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  group('ModeSelectionDialog', () {
    testWidgets('dialog displays all 6 modes', (tester) async {
      await tester.pumpWidget(buildDialogTestApp());
      await tester.pumpAndSettle();

      // Verify all 6 mode names are displayed
      expect(find.text('Convenient'), findsOneWidget);
      expect(find.text('High Scores'), findsOneWidget);
      expect(find.text('Drop Down'), findsOneWidget);
      expect(find.text('Simple Drag'), findsOneWidget);
      expect(find.text('Snake Drag'), findsOneWidget);
      expect(find.text('Arcade'), findsOneWidget);
    });

    testWidgets('dialog highlights current mode', (tester) async {
      // Default mode is convenient
      await tester.pumpWidget(buildDialogTestApp());
      await tester.pumpAndSettle();

      // The Convenient mode row should have some visual distinction.
      // We verify by checking that the dialog is displayed with
      // the current mode marked (e.g., with a check icon or highlight).
      // The exact styling depends on implementation; we verify the dialog
      // is showing with the expected mode name present.
      expect(find.text('Convenient'), findsOneWidget);

      // Look for a check icon or similar indicator near the current mode.
      // Implementation may use Icons.check, Icons.check_circle, or a
      // colored border. We verify at least one check-related icon exists.
      final checkIcons = find.byIcon(Icons.check);
      final checkCircleIcons = find.byIcon(Icons.check_circle);
      expect(
        checkIcons.evaluate().isNotEmpty ||
            checkCircleIcons.evaluate().isNotEmpty,
        isTrue,
        reason: 'Current mode should have a visual highlight indicator',
      );
    });

    testWidgets('tapping a mode calls setMode and dismisses dialog',
        (tester) async {
      await tester.pumpWidget(buildDialogTestApp());
      await tester.pumpAndSettle();

      // Tap on "High Scores" mode
      await tester.tap(find.text('High Scores'));
      await tester.pumpAndSettle();

      // Verify the mode was changed
      expect(gameState.currentMode, GameModeType.highScores);

      // Verify the dialog is dismissed (mode names no longer visible)
      expect(find.text('High Scores'), findsNothing);
    });

    testWidgets('cancel button dismisses without changing mode',
        (tester) async {
      final originalMode = gameState.currentMode;

      await tester.pumpWidget(buildDialogTestApp());
      await tester.pumpAndSettle();

      // Look for close/cancel button (could be X icon or Cancel text)
      final closeButton = find.byIcon(Icons.close);
      final cancelText = find.text('Cancel');

      if (closeButton.evaluate().isNotEmpty) {
        await tester.tap(closeButton);
      } else if (cancelText.evaluate().isNotEmpty) {
        await tester.tap(cancelText);
      } else {
        // Dismiss by tapping outside the dialog (barrier)
        await tester.tapAt(const Offset(0, 0));
      }
      await tester.pumpAndSettle();

      // Mode should be unchanged
      expect(gameState.currentMode, originalMode);
    });

    testWidgets('icons are vertically aligned', (tester) async {
      await tester.pumpWidget(buildDialogTestApp());
      await tester.pumpAndSettle();

      // Find mode icons by their specific IconData values from the enum.
      // This avoids accidentally picking up the close button or check icon.
      final List<double> xPositions = [];
      for (final mode in GameModeType.values) {
        final iconFinder = find.byIcon(mode.icon);
        expect(iconFinder, findsOneWidget,
            reason: 'Mode ${mode.name} icon should be present');
        final renderBox =
            iconFinder.evaluate().first.renderObject as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        xPositions.add(position.dx);
      }

      // All mode icons should share the same x position (vertically aligned)
      final firstX = xPositions.first;
      for (final x in xPositions) {
        expect((x - firstX).abs(), lessThan(2.0),
            reason: 'All mode icons should be vertically aligned');
      }
    });
  });
}
