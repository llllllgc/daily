import 'package:daily/app.dart';
import 'package:daily/widgets/completion_progress_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget ringHarness(int completed, {int total = 6, bool reduceMotion = false}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: CompletionProgressRing(completed: completed, total: total),
          ),
        ),
      ),
    );

CircularProgressIndicator ring(WidgetTester tester) => tester
    .widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));

void main() {
  testWidgets(
    'settled rings use red below one third, yellow until full, green at full',
    (tester) async {
      for (final (completed, color) in [
        (0, CompletionProgressRing.lowColor),
        (1, CompletionProgressRing.lowColor),
        (2, CompletionProgressRing.partialColor),
        (5, CompletionProgressRing.partialColor),
        (6, CompletionProgressRing.completeColor),
      ]) {
        await tester.pumpWidget(ringHarness(completed));
        await tester.pumpAndSettle();
        expect(ring(tester).value, completed / 6);
        expect(ring(tester).color, color);
        expect(ring(tester).semanticsValue, '${(completed / 6 * 100).round()}');
        expect(ring(tester).semanticsLabel, '完成进度，$completed / 6 已完成');
        expect(find.byType(Text), findsNothing);
      }
      await tester.pumpWidget(ringHarness(0, total: 0));
      await tester.pumpAndSettle();
      expect(ring(tester).value, 0);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets(
    'each completion grows the ring and blends between status colors',
    (tester) async {
      await tester.pumpWidget(ringHarness(1));
      await tester.pumpWidget(ringHarness(2));
      expect(ring(tester).value, 1 / 6);
      expect(ring(tester).color, CompletionProgressRing.lowColor);
      await tester.pump(const Duration(milliseconds: 130));
      expect(ring(tester).value, allOf(greaterThan(1 / 6), lessThan(2 / 6)));
      expect(ring(tester).color, isNot(CompletionProgressRing.lowColor));
      expect(ring(tester).color, isNot(CompletionProgressRing.partialColor));
      await tester.pumpAndSettle();
      expect(ring(tester).value, 2 / 6);
      expect(ring(tester).color, CompletionProgressRing.partialColor);

      await tester.pumpWidget(ringHarness(5));
      await tester.pumpAndSettle();
      await tester.pumpWidget(ringHarness(6));
      expect(ring(tester).color, CompletionProgressRing.partialColor);
      await tester.pump(const Duration(milliseconds: 260));
      expect(ring(tester).value, allOf(greaterThan(5 / 6), lessThan(1)));
      expect(ring(tester).color, isNot(CompletionProgressRing.partialColor));
      expect(ring(tester).color, isNot(CompletionProgressRing.completeColor));
      await tester.pumpAndSettle();
      expect(ring(tester).value, 1);
      expect(ring(tester).color, CompletionProgressRing.completeColor);
    },
  );

  testWidgets(
    'undo and rapid changes continue from the visible arc and color',
    (tester) async {
      await tester.pumpWidget(ringHarness(6));
      await tester.pumpWidget(ringHarness(1));
      await tester.pump(const Duration(milliseconds: 180));
      final beforeRetarget = ring(tester);
      expect(beforeRetarget.value, allOf(greaterThan(1 / 6), lessThan(1)));
      expect(beforeRetarget.color, isNot(CompletionProgressRing.completeColor));
      await tester.pumpWidget(ringHarness(5));
      expect(ring(tester).value, beforeRetarget.value);
      expect(ring(tester).color, beforeRetarget.color);
      await tester.pumpAndSettle();
      expect(ring(tester).value, 5 / 6);
      expect(ring(tester).color, CompletionProgressRing.partialColor);
      await tester.pumpWidget(ringHarness(0));
      await tester.pumpAndSettle();
      expect(ring(tester).value, 0);
      expect(ring(tester).color, CompletionProgressRing.lowColor);
    },
  );

  testWidgets('reduced motion immediately settles progress and color', (
    tester,
  ) async {
    await tester.pumpWidget(ringHarness(0, reduceMotion: true));
    await tester.pumpWidget(ringHarness(6, reduceMotion: true));
    expect(ring(tester).value, 1);
    expect(ring(tester).color, CompletionProgressRing.completeColor);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(ringHarness(0));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(ringHarness(0, reduceMotion: true));
    expect(ring(tester).value, 0);
    expect(ring(tester).color, CompletionProgressRing.lowColor);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
