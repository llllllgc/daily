import 'package:daily/widgets/button_origin_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewport = Size(390, 844);
const _source = Rect.fromLTWH(300, 64, 48, 48);

Widget _frame(double value, {bool reversing = false, bool linear = false}) =>
    MaterialApp(
      home: Scaffold(
        body: ButtonExpansionTransition(
          origin: const ButtonOrigin(bounds: _source, viewport: _viewport),
          animation: reversing
              ? ReverseAnimation(AlwaysStoppedAnimation(1 - value))
              : AlwaysStoppedAnimation(value),
          linear: linear,
          child: const Scaffold(body: Center(child: Text('Page content'))),
        ),
      ),
    );

Path _path(WidgetTester tester) {
  final finder = find.byKey(const Key('button-origin-page-clip'));
  return tester
      .widget<ClipPath>(finder)
      .clipper!
      .getClip(tester.getSize(finder));
}

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(find.byKey(const Key('button-origin-content-opacity')))
    .opacity;

double _scale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const Key('button-origin-content-scale')))
    .transform
    .storage[0];

void main() {
  testWidgets(
    'edges unfold at different rates and content stays proportional',
    (tester) async {
      await tester.binding.setSurfaceSize(_viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_frame(0));
      expect(_path(tester).getBounds(), _source);
      expect(_opacity(tester), 0);
      await tester.pumpWidget(_frame(.1));
      expect(_opacity(tester), 0);

      await tester.pumpWidget(_frame(.4));
      expect(_opacity(tester), allOf(greaterThan(0), lessThan(1)));
      final path = _path(tester);
      final bounds = path.getBounds();
      final rightProgress =
          (bounds.right - _source.right) / (_viewport.width - _source.right);
      final leftProgress = (_source.left - bounds.left) / _source.left;
      expect(rightProgress, greaterThan(leftProgress));
      final tangent = path.computeMetrics().single.getTangentForOffset(
        bounds.width * .18,
      )!;
      expect(tangent.vector.dy.abs(), greaterThan(.0001));
      final transform = tester
          .widget<Transform>(
            find.byKey(const Key('button-origin-content-scale')),
          )
          .transform;
      expect(transform.storage[0], closeTo(transform.storage[5], .000001));
      expect(_scale(tester), inInclusiveRange(.985, 1));

      await tester.pumpWidget(_frame(.4, linear: true));
      final dragPath = _path(tester);
      final dragTangent = dragPath.computeMetrics().single.getTangentForOffset(
        dragPath.getBounds().width * .18,
      )!;
      expect(dragTangent.vector.dy, closeTo(0, .0001));
    },
  );

  testWidgets(
    'content settles without a rebound and reversing preserves the frame',
    (tester) async {
      await tester.binding.setSurfaceSize(_viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var previousScale = .985;
      for (final progress in [0.0, .2, .4, .6, .72, .8, .92, 1.0]) {
        await tester.pumpWidget(_frame(progress));
        expect(_scale(tester), inInclusiveRange(previousScale, 1));
        previousScale = _scale(tester);
      }
      await tester.pumpWidget(_frame(.8));
      expect(_scale(tester), 1);
      final forwardBounds = _path(tester).getBounds();
      final forwardScale = _scale(tester);
      final forwardOpacity = _opacity(tester);
      await tester.pumpWidget(_frame(.8, reversing: true));
      expect(_path(tester).getBounds(), forwardBounds);
      expect(_scale(tester), forwardScale);
      expect(_opacity(tester), forwardOpacity);

      await tester.pumpWidget(_frame(.92));
      expect(_scale(tester), 1);
      await tester.pumpWidget(_frame(1));
      expect(_path(tester).getBounds(), Offset.zero & _viewport);
      expect(_opacity(tester), 1);
      expect(_scale(tester), 1);
      await tester.pumpWidget(_frame(0, reversing: true));
      expect(_path(tester).getBounds(), _source);
      expect(_opacity(tester), 0);
      expect(tester.takeException(), isNull);
    },
  );
}
