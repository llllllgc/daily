import 'package:daily/app.dart';
import 'package:daily/models.dart';
import 'package:daily/pages/item_detail_page.dart';
import 'package:daily/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<MemoryDailyStore> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryDailyStore(
      seedItems: [
        ReminderItem(
          title: '练习',
          iconKey: 'study',
          startDate: dateOnly(DateTime.now()),
          repeatKind: RepeatKind.interval,
          intervalDays: 3,
          times: const [ReminderTime(minuteOfDay: 540, sortOrder: 0)],
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
    return store;
  }

  testWidgets('double tapping a calendar card opens details with counters', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('练习'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('练习'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailPage), findsOneWidget);
    expect(find.text('漏做 0 次'), findsOneWidget);
    expect(find.text('已跳过 0 次'), findsOneWidget);
    expect(find.text('暂停 0 次'), findsOneWidget);
    expect(find.text('每 3 天 · 当天 1 次'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('double tapping management opens details without editing', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('tab-items')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('练习'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('练习'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailPage), findsOneWidget);
    expect(find.byType(ItemEditorPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('long press skips one occurrence and retains the note', (
    tester,
  ) async {
    final store = await open(tester);
    await tester.longPress(find.text('练习'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跳过本次'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '出差');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final records = await store.history.recordsFor(
      (await store.loadItems()).single.id!,
    );
    expect(records.single.status, OccurrenceStatus.skipped);
    expect(records.single.note, '出差');
    expect(find.text('已跳过'), findsOneWidget);
    expect(find.text('已完成 0/1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
