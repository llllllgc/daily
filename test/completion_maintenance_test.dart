import 'package:daily/app.dart';
import 'package:daily/models.dart';
import 'package:daily/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ObservedStore extends MemoryDailyStore {
  _ObservedStore({super.seedItems});
  final rangeReads = <(DateTime?, DateTime?)>[];
  int fullRecordReads = 0;
  @override
  Future<Map<String, Map<String, Object?>>> loadJournal(
    String kind, {
    String? key,
    DateTime? from,
    DateTime? to,
  }) {
    if (kind == 'records') {
      if (key == null && from == null && to == null) fullRecordReads++;
      if (from != null || to != null) rangeReads.add((from, to));
    }
    return super.loadJournal(kind, key: key, from: from, to: to);
  }
}

class _ObservedScheduler extends NoopReminderScheduler {
  int syncs = 0;
  @override
  Future<void> sync(List<ReminderItem> items) async {
    syncs++;
  }
}

void main() {
  testWidgets(
    'completion stays local during movement and coalesces maintenance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final today = dateOnly(DateTime.now());
      final store = _ObservedStore(
        seedItems: [
          for (var i = 0; i < 2; i++)
            ReminderItem(
              title: '事项 $i',
              iconKey: 'medication',
              startDate: today,
              repeatKind: RepeatKind.daily,
              stockQuantity: 10,
              times: [ReminderTime(minuteOfDay: 540 + i * 60, sortOrder: 0)],
            ),
        ],
      );
      final scheduler = _ObservedScheduler();
      await tester.pumpWidget(
        DailyApp(
          store: store,
          scheduler: scheduler,
          refreshSignal: AppRefreshSignal(),
        ),
      );
      await tester.pumpAndSettle();
      store.rangeReads.clear();
      store.fullRecordReads = 0;
      final initialSyncs = scheduler.syncs;
      final items = await store.loadItems();
      await tester.tap(find.byKey(ValueKey('completion-${items.first.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      expect(find.text('已完成 1/2'), findsOneWidget);
      expect(find.text('剩余 9 片'), findsOneWidget);
      expect(store.rangeReads, isEmpty);
      expect(store.fullRecordReads, 0);
      expect(scheduler.syncs, initialSyncs);
      await tester.tap(find.byKey(ValueKey('completion-${items.last.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('已完成 2/2'), findsOneWidget);
      expect(store.rangeReads, isEmpty);
      expect(scheduler.syncs, initialSyncs);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(scheduler.syncs, initialSyncs + 1);
      expect(store.fullRecordReads, 0);
      expect(
        store.rangeReads.every(
          (range) =>
              range.$1 == today &&
              range.$2 == today.add(const Duration(days: 30)),
        ),
        true,
      );
      expect(await store.completionCount(), 2);
      expect(tester.takeException(), isNull);
    },
  );
}
