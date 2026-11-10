import 'package:daily/app.dart';
import 'package:daily/models.dart';
import 'package:daily/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'missed status stays beside the title without changing row height',
    (tester) async {
      final yesterday = dateOnly(
        DateTime.now(),
      ).subtract(const Duration(days: 1));
      final store = MemoryDailyStore(
        seedItems: [
          ReminderItem(
            title: '日常事项',
            iconKey: 'medication',
            startDate: yesterday,
            repeatKind: RepeatKind.daily,
            times: const [ReminderTime(minuteOfDay: 540, sortOrder: 0)],
          ),
        ],
      );
      final group = (await store.history.loadDay(yesterday)).single;
      final completed = ValueNotifier(false);
      addTearDown(completed.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: ValueListenableBuilder(
                valueListenable: completed,
                builder: (context, done, _) => TaskGroupView(
                  group: DayTaskGroup(
                    item: group.item,
                    date: group.date,
                    completedKeys: done
                        ? {
                            completionKey(
                              group.item.id!,
                              group.item.times.single.id!,
                              yesterday,
                            ),
                          }
                        : {},
                    records: {
                      for (final entry in group.records.entries)
                        entry.key: entry.value.copyWith(
                          status: done
                              ? OccurrenceStatus.completed
                              : OccurrenceStatus.missed,
                        ),
                    },
                  ),
                  expanded: false,
                  onToggleExpanded: null,
                  onToggleCompletion: (_) => completed.value = !completed.value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final height = tester.getSize(find.byType(TaskGroupView)).height;
      final title = tester.getRect(find.text('日常事项'));
      final status = tester.getRect(find.text('漏做'));
      expect(status.left - title.right, inInclusiveRange(16, 28));
      expect(status.center.dy, closeTo(title.center.dy, 2));
      for (final done in [true, false, true, false]) {
        completed.value = done;
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(TaskGroupView)).height, height);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.7]) {
      testWidgets('stock exhaustion keeps row height at $width / $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final date = dateOnly(DateTime.now()).subtract(const Duration(days: 1));
        final item = ReminderItem(
          id: 1,
          title: '需要显示省略号的很长很长的事项名称',
          iconKey: 'medication',
          startDate: date,
          repeatKind: RepeatKind.daily,
          stockQuantity: 1,
          expiryDate: date.add(const Duration(days: 30)),
          times: const [
            ReminderTime(id: 1, itemId: 1, minuteOfDay: 540, sortOrder: 0),
          ],
        );
        final done = ValueNotifier(false);
        addTearDown(done.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ValueListenableBuilder(
                      valueListenable: done,
                      builder: (context, value, _) => TaskGroupView(
                        group: DayTaskGroup(
                          item: item.copyWith(usedQuantity: value ? 1 : 0),
                          date: date,
                          completedKeys: value
                              ? {completionKey(1, 1, date)}
                              : {},
                          records: {
                            completionKey(1, 1, date): OccurrenceRecord(
                              item: item,
                              time: item.times.single,
                              date: date,
                              status: value
                                  ? OccurrenceStatus.completed
                                  : OccurrenceStatus.missed,
                              changedAt: DateTime.now(),
                            ),
                          },
                        ),
                        expanded: false,
                        onToggleExpanded: null,
                        onToggleCompletion: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final height = tester.getSize(find.byType(TaskGroupView)).height;
        expect(find.text('漏做'), findsOneWidget);
        for (final value in [true, false]) {
          done.value = value;
          await tester.pumpAndSettle();
          expect(tester.getSize(find.byType(TaskGroupView)).height, height);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('six successive completions rebuild only the changed cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(
      seedItems: [
        for (var i = 0; i < 6; i++)
          ReminderItem(
            title: '事项 $i',
            iconKey: 'medication',
            startDate: today,
            repeatKind: RepeatKind.daily,
            times: [ReminderTime(minuteOfDay: 540 + i * 60, sortOrder: 0)],
          ),
      ],
    );
    await tester.pumpWidget(
      DailyApp(
        store: store,
        scheduler: const NoopReminderScheduler(),
        refreshSignal: AppRefreshSignal(),
      ),
    );
    await tester.pumpAndSettle();
    final items = await store.loadItems();
    var cardBuilds = 0;
    var shellBuilds = 0;
    var itemsBuilds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is TaskGroupView) cardBuilds++;
      if (element.widget is DailyShell) shellBuilds++;
      if (element.widget is ItemsPage) itemsBuilds++;
      previous?.call(element, builtOnce);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    final heights = {
      for (final item in items)
        item.id: tester
            .getSize(find.byKey(ValueKey('group-${item.id}')))
            .height,
    };
    for (var index = 0; index < items.length; index++) {
      await tester.tap(find.byKey(ValueKey('completion-${items[index].id}')));
      await tester.pump();
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('已完成 ${index + 1}/6'), findsOneWidget);
      for (final item in items) {
        expect(
          tester.getSize(find.byKey(ValueKey('group-${item.id}'))).height,
          heights[item.id],
        );
      }
    }
    // ignore: avoid_print
    print('Task card rebuilds for six completions: $cardBuilds');
    expect(cardBuilds, 6);
    await tester.pumpAndSettle();
    expect(await store.completionCount(), 6);
    expect(
      cardBuilds,
      6,
      reason: 'maintenance must not rebuild the unchanged calendar',
    );
    expect(
      shellBuilds,
      0,
      reason: 'completion maintenance must not rebuild the shell',
    );
    expect(
      itemsBuilds,
      0,
      reason: 'defer the hidden tab refresh until it opens',
    );
    // Pumped animation time does not advance DateTime.now's double-tap guard.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 130)),
    );
    cardBuilds = 0;
    for (var index = items.length - 1; index >= 0; index--) {
      await tester.tap(find.byKey(ValueKey('completion-${items[index].id}')));
      await tester.pump();
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('已完成 $index/6'), findsOneWidget);
    }
    await tester.pumpAndSettle();
    expect(cardBuilds, 6);
    expect(await store.completionCount(), 0);
    expect(tester.takeException(), isNull);
  });
}
