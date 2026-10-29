import 'package:daily/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _captureKey = Key('completion-capture');

Widget buttonHarness(
  ValueNotifier<bool> completed,
  ValueNotifier<bool> reduceMotion,
) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Center(
        child: ListenableBuilder(
          listenable: Listenable.merge([completed, reduceMotion]),
          builder: (context, _) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion.value),
            child: RepaintBoundary(
              key: _captureKey,
              child: ColoredBox(
                color: AppPalette.canvas,
                child: SizedBox.square(
                  dimension: 64,
                  child: Center(
                    child: CompletionButton(
                      completed: completed.value,
                      onPressed: () => completed.value = !completed.value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ButtonFrame {
  ButtonFrame(this.width, this.pixels);

  final int width;
  final Uint8List pixels;

  bool _matches(int index, Color color) {
    final argb = color.toARGB32();
    return (pixels[index] - ((argb >> 16) & 255)).abs() <= 2 &&
        (pixels[index + 1] - ((argb >> 8) & 255)).abs() <= 2 &&
        (pixels[index + 2] - (argb & 255)).abs() <= 2;
  }

  int count(Color color) {
    var count = 0;
    for (var index = 0; index < pixels.length; index += 4) {
      if (_matches(index, color)) count++;
    }
    return count;
  }

  int filledWidth() {
    var left = width;
    var right = -1;
    for (var index = 0; index < pixels.length; index += 4) {
      if (!_matches(index, AppPalette.pine)) continue;
      final x = (index ~/ 4) % width;
      if (x < left) left = x;
      if (x > right) right = x;
    }
    return right < left ? 0 : right - left + 1;
  }
}

Future<ButtonFrame> captureButton(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 4);
    try {
      final data = await image.toByteData();
      return ButtonFrame(image.width, data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  testWidgets('completion fills outward, pops, and draws a continuous check', (
    tester,
  ) async {
    final completed = ValueNotifier(false);
    final reduceMotion = ValueNotifier(false);
    addTearDown(completed.dispose);
    addTearDown(reduceMotion.dispose);
    await tester.pumpWidget(buttonHarness(completed, reduceMotion));
    final empty = await captureButton(tester);
    expect(empty.count(AppPalette.pine), 0);

    completed.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final filling = await captureButton(tester);
    await tester.pump(const Duration(milliseconds: 80));
    final filled = await captureButton(tester);
    expect(filling.count(AppPalette.pine), greaterThan(0));
    expect(
      filled.count(AppPalette.pine),
      greaterThan(filling.count(AppPalette.pine)),
    );
    expect(filled.count(AppPalette.pineInk), 0);

    await tester.pump(const Duration(milliseconds: 90));
    final popping = await captureButton(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final drawn = await captureButton(tester);
    expect(popping.count(AppPalette.pineInk), greaterThan(0));
    expect(
      drawn.count(AppPalette.pineInk),
      greaterThan(popping.count(AppPalette.pineInk)),
    );

    await tester.pumpAndSettle();
    final settled = await captureButton(tester);
    expect(popping.filledWidth(), greaterThan(settled.filledWidth()));
    expect(settled.count(AppPalette.pineInk), greaterThan(0));
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      tester.getSize(find.byType(CompletionButton)),
      const Size.square(48),
    );
  });

  testWidgets(
    'undo and rapid retarget keep the current drawing without jumps',
    (tester) async {
      final completed = ValueNotifier(false);
      final reduceMotion = ValueNotifier(false);
      addTearDown(completed.dispose);
      addTearDown(reduceMotion.dispose);
      await tester.pumpWidget(buttonHarness(completed, reduceMotion));
      completed.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final beforeUndo = await captureButton(tester);
      completed.value = false;
      await tester.pump();
      expect(
        (await captureButton(tester)).pixels,
        orderedEquals(beforeUndo.pixels),
      );

      await tester.pump(const Duration(milliseconds: 20));
      final beforeRedo = await captureButton(tester);
      completed.value = true;
      await tester.pump();
      expect(
        (await captureButton(tester)).pixels,
        orderedEquals(beforeRedo.pixels),
      );
      await tester.pumpAndSettle();
      completed.value = false;
      await tester.pumpAndSettle();
      expect((await captureButton(tester)).count(AppPalette.pine), 0);

      completed.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets('reduced motion settles on entry and during completion', (
    tester,
  ) async {
    final completed = ValueNotifier(false);
    final reduceMotion = ValueNotifier(true);
    addTearDown(completed.dispose);
    addTearDown(reduceMotion.dispose);
    await tester.pumpWidget(buttonHarness(completed, reduceMotion));
    completed.value = true;
    await tester.pump();
    final immediate = await captureButton(tester);
    expect(immediate.count(AppPalette.pineInk), greaterThan(0));
    expect(tester.hasRunningAnimations, isFalse);

    reduceMotion.value = false;
    completed.value = false;
    await tester.pumpAndSettle();
    completed.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    reduceMotion.value = true;
    await tester.pump();
    expect(
      (await captureButton(tester)).pixels,
      orderedEquals(immediate.pixels),
    );
    expect(tester.hasRunningAnimations, isFalse);

    reduceMotion.value = false;
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('completion remains keyboard accessible', (tester) async {
    final completed = ValueNotifier(false);
    final reduceMotion = ValueNotifier(false);
    addTearDown(completed.dispose);
    addTearDown(reduceMotion.dispose);
    await tester.pumpWidget(buttonHarness(completed, reduceMotion));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(completed.value, isTrue);
    expect(find.byTooltip('撤销完成'), findsOneWidget);
  });
}
