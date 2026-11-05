import 'package:daily/app.dart';
import 'package:daily/models.dart';
import 'package:daily/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingStore extends MemoryDailyStore {
  int itemReads = 0;

  @override
  Future<List<ReminderItem>> loadItems({bool includeArchived = false}) {
    itemReads++;
    return super.loadItems(includeArchived: includeArchived);
  }
}

class _CountingScheduler extends NoopReminderScheduler {
  int syncs = 0;

  @override
  Future<void> sync(List<ReminderItem> items) async => syncs++;
}

void main() {
  testWidgets('returning from settings keeps plans and notifications intact', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _CountingStore();
    final scheduler = _CountingScheduler();
    await tester.pumpWidget(
      DailyApp(
        store: store,
        scheduler: scheduler,
        refreshSignal: AppRefreshSignal(),
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in ['calendar', 'items']) {
      await tester.tap(find.byKey(Key('tab-$tab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('$tab-settings-button')));
      await tester.pumpAndSettle();
      final reads = store.itemReads;
      final syncs = scheduler.syncs;
      await tester.tap(find.byTooltip('返回'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(store.itemReads, reads);
      expect(scheduler.syncs, syncs);
      await tester.pumpAndSettle();
      expect(store.itemReads, reads);
      expect(scheduler.syncs, syncs);
      expect(find.byType(SettingsPage), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('duration includes its first day and combines with recurrence', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryDailyStore();
    var item = await store.saveItem(
      ReminderItem(
        title: '短期安排',
        iconKey: 'medication',
        startDate: DateTime(2026, 12, 30),
        repeatKind: RepeatKind.interval,
        intervalDays: 2,
        times: const [
          ReminderTime(minuteOfDay: 540, sortOrder: 0),
          ReminderTime(minuteOfDay: 1200, sortOrder: 1),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => ItemEditorPage(store: store, item: item),
                ),
              ),
              child: const Text('编辑'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-date-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('持续几天'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('duration-picker-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('2026/12/30\n至 2027/01/05'), findsOneWidget);
    await tester.tap(find.byKey(const Key('editor-date-range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final firstRangeFields = find.descendant(
      of: find.byType(DateRangePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(firstRangeFields.at(0), '01/30/2027');
    await tester.enterText(firstRangeFields.at(1), '02/05/2027');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('2027/01/30\n至 2027/02/05'), findsOneWidget);
    expect(find.text('7 天'), findsOneWidget);
    await tester.tap(find.byKey(const Key('editor-sheet-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-item-button')));
    await tester.pumpAndSettle();
    item = (await store.loadItems()).single;
    expect(item.startDate, DateTime(2027, 1, 30));
    expect(item.endDate, DateTime(2027, 2, 5));
    expect(item.repeatKind, RepeatKind.interval);
    expect(item.times.length, 2);
    final days = await store.history.loadDays(
      DateTime(2027, 1, 30),
      DateTime(2027, 2, 6),
    );
    expect(days.values.expand((groups) => groups).length, 4);
    expect(days[dayKey(DateTime(2027, 2, 6))], isEmpty);

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-date-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editor-date-range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final rangeFields = find.descendant(
      of: find.byType(DateRangePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(rangeFields.at(0), '01/30/2027');
    await tester.enterText(rangeFields.at(1), '01/30/2027');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('2027/01/30\n至 2027/01/30'), findsOneWidget);
    expect(find.text('1 天'), findsOneWidget);
    await tester.tap(find.byKey(const Key('editor-sheet-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-item-button')));
    await tester.pumpAndSettle();
    item = (await store.loadItems()).single;
    expect(item.endDate, item.startDate);
    expect(
      item.isScheduledOn(item.startDate.add(const Duration(days: 2))),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
