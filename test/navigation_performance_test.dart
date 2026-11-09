import 'package:daily/app.dart';
import 'package:daily/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('calendar expansion computes each day status once', (
    tester,
  ) async {
    final expanded = ValueNotifier(false);
    addTearDown(expanded.dispose);
    var statusReads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: expanded,
            builder: (context, value, _) => CalendarDates(
              expanded: value,
              visibleMonth: DateTime(2026, 11),
              selectedDate: DateTime(2026, 11, 9),
              statusFor: (_) {
                statusReads++;
                return null;
              },
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(statusReads, 7);
    statusReads = 0;
    expanded.value = true;
    await tester.pump();
    for (var i = 0; i < 22; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(statusReads, 42);
    expect(find.byType(CalendarDayCell), findsNWidgets(42));
    expanded.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDayCell), findsNWidgets(7));
  });

  testWidgets('calendar swipe reuses adjacent dates until data changes', (
    tester,
  ) async {
    final revision = ValueNotifier(0);
    addTearDown(revision.dispose);
    var adjacentBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: revision,
            builder: (context, value, _) => SwipePeriod(
              onChanged: (_) {},
              adjacentBuilder: (_) {
                adjacentBuilds++;
                return SizedBox(height: 100, child: Text('week $value'));
              },
              child: const SizedBox(height: 100, width: double.infinity),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SwipePeriod)),
    );
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(-5, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(adjacentBuilds, 1);
    revision.value++;
    await tester.pump();
    expect(adjacentBuilds, 2);
    expect(find.text('week 1'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
