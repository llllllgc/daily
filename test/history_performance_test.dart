import 'package:daily/app.dart';
import 'package:daily/models.dart';
import 'package:daily/pages/item_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _DetailStore extends MemoryDailyStore {
  _DetailStore({super.seedItems});
  int todayReads = 0;
  int itemReads = 0;
  @override
  Future<Map<String, Map<String, Object?>>> loadJournal(
    String kind, {
    String? key,
    DateTime? from,
    DateTime? to,
  }) {
    if (kind == 'records' && from != null && from == to) todayReads++;
    return super.loadJournal(kind, key: key, from: from, to: to);
  }

  @override
  Future<List<OccurrenceRecord>> loadRecordsForItem(int itemId) {
    itemReads++;
    return super.loadRecordsForItem(itemId);
  }
}

void main() {
  testWidgets('detail loads today once and uses the selected item query', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    final store = _DetailStore(
      seedItems: [
        ReminderItem(
          title: '目标事项',
          iconKey: 'study',
          startDate: today,
          repeatKind: RepeatKind.daily,
          times: const [ReminderTime(minuteOfDay: 540, sortOrder: 0)],
        ),
      ],
    );
    await store.history.reconcile();
    final item = (await store.loadItems()).single;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ItemDetailPage(store: store, item: item, onChanged: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.todayReads, 1);
    expect(store.itemReads, 1);
    expect(find.text('目标事项'), findsOneWidget);
  });

  test('month lookup preserves effective versions across many items', () async {
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(
      seedItems: [
        for (var i = 0; i < 80; i++)
          ReminderItem(
            title: '事项 $i',
            iconKey: 'study',
            startDate: today.subtract(const Duration(days: 240)),
            repeatKind: RepeatKind.daily,
            times: const [ReminderTime(minuteOfDay: 540, sortOrder: 0)],
          ),
      ],
    );
    await store.history.ensureVersions();
    final items = await store.loadItems();
    await store.writeJournal('versions', {
      for (final item in items)
        for (var version = 0; version < 8; version++)
          '${item.id}:${dayKey(today.add(Duration(days: version * 4)))}': {
            'from': dayKey(today.add(Duration(days: version * 4))),
            'item': itemToJson(item.copyWith(title: '${item.title} v$version')),
          },
    });
    await store.writeJournal('meta', {
      'reconciled': {
        'through': dayKey(today.subtract(const Duration(days: 1))),
      },
    });
    final elapsed = <int>[];
    for (var run = 0; run < 3; run++) {
      final watch = Stopwatch()..start();
      final days = await store.history.loadDays(
        today,
        today.add(const Duration(days: 41)),
      );
      elapsed.add(watch.elapsedMilliseconds);
      for (var day = 0; day < 42; day++) {
        final groups = days[dayKey(today.add(Duration(days: day)))]!;
        expect(groups, hasLength(80));
        expect(groups.first.item.title, '事项 0 v${(day ~/ 4).clamp(0, 7)}');
      }
    }
    // Diagnostic timing only; correctness assertions do not depend on CPU speed.
    // ignore: avoid_print
    print('80 items / 720 versions / 42 days: $elapsed ms');
  });
}
