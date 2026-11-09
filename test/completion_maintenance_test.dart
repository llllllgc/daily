import 'dart:async';

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

class _SlowCompletionStore extends MemoryDailyStore {
  _SlowCompletionStore({super.seedItems});
  final writes = <(bool, Completer<void>)>[];

  @override
  Future<void> setCompletion({
    required int itemId,
    required int reminderTimeId,
    required DateTime date,
    required bool completed,
    DateTime? completedAt,
  }) async {
    final gate = Completer<void>();
    writes.add((completed, gate));
    await gate.future;
    await super.setCompletion(
      itemId: itemId,
      reminderTimeId: reminderTimeId,
      date: date,
      completed: completed,
      completedAt: completedAt,
    );
  }
}

void main() {
  for (final results in [(true, true), (true, false), (false, false)]) {
    testWidgets('slow completion and undo stay responsive: $results', (
      tester,
    ) async {
      final today = dateOnly(DateTime.now());
      final store = _SlowCompletionStore(
        seedItems: [
          ReminderItem(
            title: '慢速保存',
            iconKey: 'medication',
            startDate: today,
            repeatKind: RepeatKind.daily,
            stockQuantity: 10,
            times: [ReminderTime(minuteOfDay: 540, sortOrder: 0)],
          ),
        ],
      );
      final scheduler = _ObservedScheduler();
      final refresh = AppRefreshSignal();
      await tester.pumpWidget(
        DailyApp(store: store, scheduler: scheduler, refreshSignal: refresh),
      );
      await tester.pumpAndSettle();
      final item = (await store.loadItems()).single;
      final button = find.byKey(ValueKey('completion-${item.id}'));
      await tester.tap(button);
      await tester.pump();
      expect(find.text('已完成 1/1'), findsOneWidget);
      expect(find.text('剩余 9 片'), findsOneWidget);
      expect(store.writes, hasLength(1));
      refresh.notify();
      await tester.pumpAndSettle();
      expect(find.text('已完成 1/1'), findsOneWidget);
      expect(find.text('剩余 9 片'), findsOneWidget);
      // A deliberate reversal during a slow write must not be dropped.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 130)),
      );
      await tester.tap(button);
      await tester.pump();
      expect(find.text('已完成 0/1'), findsOneWidget);
      expect(find.text('剩余 10 片'), findsOneWidget);
      expect(store.writes, hasLength(1));
      if (results.$1) {
        store.writes[0].$2.complete();
      } else {
        store.writes[0].$2.completeError(StateError('write failed'));
      }
      await tester.pump();
      expect(store.writes, hasLength(2));
      expect(store.writes.map((write) => write.$1), [true, false]);
      // Completion of an older write must not reverse the newer UI state.
      expect(find.text('已完成 0/1'), findsOneWidget);
      if (results.$2) {
        store.writes[1].$2.complete();
      } else {
        store.writes[1].$2.completeError(StateError('write failed'));
      }
      await tester.pumpAndSettle();
      final savedComplete = results.$1 && !results.$2;
      expect(await store.completionCount(), savedComplete ? 1 : 0);
      expect(find.text('已完成 ${savedComplete ? 1 : 0}/1'), findsOneWidget);
      expect(find.text('剩余 ${savedComplete ? 9 : 10} 片'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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
