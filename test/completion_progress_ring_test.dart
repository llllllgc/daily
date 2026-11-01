import 'package:daily/app.dart';
import 'package:daily/widgets/completion_progress_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _captureKey = Key('progress-ring-capture');

Widget ringHarness(int completed, {int total = 6, bool reduceMotion = false}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: _captureKey,
              child: CompletionProgressRing(completed: completed, total: total),
            ),
          ),
        ),
      ),
    );

CircularProgressIndicator ring(WidgetTester tester) => tester
    .widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));

Future<int> checkPixelCount(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 4);
    try {
      final data = await image.toByteData();
      final pixels = data!.buffer.asUint8List();
      final argb = CompletionProgressRing.completeColor.toARGB32();
      var count = 0;
      // The center contains only the check; exclude the surrounding ring.
      for (var y = (image.height * .25).ceil(); y < image.height * .75; y++) {
        for (var x = (image.width * .25).ceil(); x < image.width * .75; x++) {
          final index = (y * image.width + x) * 4;
          if ((pixels[index] - ((argb >> 16) & 255)).abs() <= 2 &&
              (pixels[index + 1] - ((argb >> 8) & 255)).abs() <= 2 &&
              (pixels[index + 2] - (argb & 255)).abs() <= 2 &&
              pixels[index + 3] == 255) {
            count++;
          }
        }
      }
      return count;
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  testWidgets(
    'rings are 20 percent smaller and stay red through exactly one third',
    (tester) async {
      for (final (completed, color) in [
        (0, CompletionProgressRing.lowColor),
        (1, CompletionProgressRing.lowColor),
        (2, CompletionProgressRing.lowColor),
        (3, CompletionProgressRing.partialColor),
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
        expect(
          tester.getSize(find.byKey(_captureKey)),
          const Size.square(25.6),
        );
        expect(ring(tester).strokeWidth, closeTo(2.8, .00001));
      }
      await tester.pumpWidget(ringHarness(0, total: 0));
      await tester.pumpAndSettle();
      expect(ring(tester).value, 0);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(ringHarness(1, total: 3));
      await tester.pumpAndSettle();
      expect(ring(tester).color, CompletionProgressRing.lowColor);
    },
  );

  testWidgets(
    'each completion grows the ring and blends between status colors',
    (tester) async {
      await tester.pumpWidget(ringHarness(1));
      await tester.pumpWidget(ringHarness(3));
      expect(ring(tester).value, 1 / 6);
      expect(ring(tester).color, CompletionProgressRing.lowColor);
      await tester.pump(const Duration(milliseconds: 130));
      expect(ring(tester).value, allOf(greaterThan(1 / 6), lessThan(3 / 6)));
      expect(ring(tester).color, isNot(CompletionProgressRing.lowColor));
      expect(ring(tester).color, isNot(CompletionProgressRing.partialColor));
      await tester.pumpAndSettle();
      expect(ring(tester).value, 3 / 6);
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

  testWidgets('the check draws after the ring closes and retracts on undo', (
    tester,
  ) async {
    await tester.pumpWidget(ringHarness(5));
    expect(await checkPixelCount(tester), 0);
    await tester.pumpWidget(ringHarness(6));
    await tester.pump(const Duration(milliseconds: 500));
    expect(ring(tester).value, lessThan(1));
    expect(await checkPixelCount(tester), 0);

    await tester.pump(const Duration(milliseconds: 80));
    expect(ring(tester).value, 1);
    final drawing = await checkPixelCount(tester);
    expect(drawing, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(await checkPixelCount(tester), greaterThan(drawing));
    await tester.pumpAndSettle();
    final complete = await checkPixelCount(tester);
    expect(complete, greaterThan(drawing));

    await tester.pumpWidget(ringHarness(5));
    expect(await checkPixelCount(tester), complete);
    await tester.pump(const Duration(milliseconds: 100));
    expect(await checkPixelCount(tester), lessThan(complete));
    await tester.pumpAndSettle();
    expect(await checkPixelCount(tester), 0);
  });

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
    expect(await checkPixelCount(tester), greaterThan(0));
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(ringHarness(0));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(ringHarness(0, reduceMotion: true));
    expect(ring(tester).value, 0);
    expect(ring(tester).color, CompletionProgressRing.lowColor);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
