import 'package:daily/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe({required this.onLayout, required super.child});
  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) => _ProbeBox(onLayout);
}

class _ProbeBox extends RenderProxyBox {
  _ProbeBox(this.onLayout);
  final VoidCallback onLayout;

  @override
  void performLayout() {
    onLayout();
    super.performLayout();
  }
}

void main() {
  testWidgets('card fill repaints without rebuilding or laying out content', (
    tester,
  ) async {
    final completed = ValueNotifier(false);
    final reduceMotion = ValueNotifier(false);
    addTearDown(completed.dispose);
    addTearDown(reduceMotion.dispose);
    var builds = 0;
    var layouts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: Listenable.merge([completed, reduceMotion]),
          builder: (context, _) => MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion.value),
            child: Center(
              child: CompletionFillSurface(
                completed: completed.value,
                baseColor: Colors.white,
                completedColor: Colors.green,
                borderRadius: BorderRadius.circular(20),
                child: Builder(
                  builder: (context) {
                    builds++;
                    return _LayoutProbe(
                      onLayout: () => layouts++,
                      child: const SizedBox(width: 300, height: 80),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    double progress() =>
        (tester
                    .widget<CustomPaint>(
                      find.byKey(const Key('completion-fill')),
                    )
                    .painter!
                as CompletionFillPainter)
            .progress
            .value;
    completed.value = true;
    await tester.pump();
    final initialBuilds = builds;
    final initialLayouts = layouts;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(progress(), inExclusiveRange(0, 1));
    expect(builds, initialBuilds);
    expect(layouts, initialLayouts);

    final beforeUndo = progress();
    completed.value = false;
    await tester.pump();
    expect(progress(), beforeUndo);
    await tester.pump(const Duration(milliseconds: 50));
    expect(progress(), lessThan(beforeUndo));
    reduceMotion.value = true;
    await tester.pump();
    expect(progress(), 0);
    completed.value = true;
    await tester.pump();
    expect(progress(), 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
