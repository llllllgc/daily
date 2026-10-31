import 'package:daily/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'calendar status distinguishes future pending partial and missed days',
    () {
      final today = DateTime(2026, 10, 19);

      expect(
        dayRecordStatus(
          date: today.add(const Duration(days: 1)),
          today: today,
          completed: 0,
          total: 2,
        ),
        DayRecordStatus.none,
      );
      expect(
        dayRecordStatus(date: today, today: today, completed: 0, total: 2),
        DayRecordStatus.pending,
      );
      expect(
        dayRecordStatus(date: today, today: today, completed: 1, total: 2),
        DayRecordStatus.partial,
      );
      expect(
        dayRecordStatus(
          date: today.subtract(const Duration(days: 1)),
          today: today,
          completed: 1,
          total: 2,
        ),
        DayRecordStatus.missed,
      );
      expect(
        dayRecordStatus(date: today, today: today, completed: 2, total: 2),
        DayRecordStatus.complete,
      );
    },
  );

  test('weekly recurrence respects weekday and date range', () {
    final item = ReminderItem(
      title: '运动',
      iconKey: 'exercise',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 31),
      repeatKind: RepeatKind.weekly,
      weekdays: const {1, 3, 5},
      times: const [ReminderTime(id: 1, minuteOfDay: 420, sortOrder: 0)],
    );

    expect(item.isScheduledOn(DateTime(2026, 10, 16)), isTrue);
    expect(item.isScheduledOn(DateTime(2026, 10, 17)), isFalse);
    expect(item.isScheduledOn(DateTime(2026, 11, 2)), isFalse);
  });

  test('interval recurrence stays anchored to calendar days across months', () {
    final item = ReminderItem(
      title: '隔三天用药',
      iconKey: 'medication',
      startDate: DateTime(2026, 10, 30),
      repeatKind: RepeatKind.interval,
      intervalDays: 3,
      times: const [ReminderTime(minuteOfDay: 540, sortOrder: 0)],
    );

    expect(item.scheduleLabel, '每 3 天');
    expect(item.isScheduledOn(DateTime(2026, 10, 30)), isTrue);
    expect(item.isScheduledOn(DateTime(2026, 11, 1)), isFalse);
    expect(item.isScheduledOn(DateTime(2026, 11, 2)), isTrue);
    expect(item.isScheduledOn(DateTime(2026, 11, 5)), isTrue);
  });

  test(
    'inventory records actual dose and restores it on undo or deletion',
    () async {
      final store = MemoryDailyStore(
        seedItems: [
          ReminderItem(
            title: '药片',
            iconKey: 'medication',
            startDate: DateTime(2026, 10, 1),
            repeatKind: RepeatKind.daily,
            stockQuantity: 10,
            doseQuantity: 1.5,
            stockUnit: '片',
            productionDate: DateTime(2026, 1, 1),
            expiryDate: DateTime(2027, 1, 1),
            times: const [ReminderTime(minuteOfDay: 540, sortOrder: 0)],
          ),
        ],
      );
      var item = (await store.loadItems()).single;
      final date = DateTime(2026, 10, 1);
      await store.setCompletion(
        itemId: item.id!,
        reminderTimeId: item.times.single.id!,
        date: date,
        completed: true,
      );
      await store.setCompletion(
        itemId: item.id!,
        reminderTimeId: item.times.single.id!,
        date: date,
        completed: true,
      );
      item = (await store.loadItems()).single;
      expect(item.remainingQuantity, 8.5);
      expect(item.productionDate, DateTime(2026, 1, 1));
      expect(item.expiryDate, DateTime(2027, 1, 1));

      await store.saveItem(item.copyWith(doseQuantity: 2));
      expect((await store.loadItems()).single.remainingQuantity, 8.5);
      final deleted = await store.deleteItem(item.id!);
      expect(deleted, isNotNull);
      await store.restoreDeletedItem(deleted!);
      item = (await store.loadItems()).single;
      expect(item.remainingQuantity, 8.5);

      await store.setCompletion(
        itemId: item.id!,
        reminderTimeId: item.times.single.id!,
        date: date,
        completed: false,
      );
      expect((await store.loadItems()).single.remainingQuantity, 10);
    },
  );

  test('removing a reminder time keeps medicine already used', () async {
    final store = MemoryDailyStore(
      seedItems: [
        ReminderItem(
          title: '药片',
          iconKey: 'medication',
          startDate: DateTime(2026, 10, 1),
          repeatKind: RepeatKind.daily,
          stockQuantity: 6,
          doseQuantity: 1,
          times: const [
            ReminderTime(minuteOfDay: 540, sortOrder: 0),
            ReminderTime(minuteOfDay: 1020, sortOrder: 1),
          ],
        ),
      ],
    );
    var item = (await store.loadItems()).single;
    await store.setCompletion(
      itemId: item.id!,
      reminderTimeId: item.times.first.id!,
      date: DateTime(2026, 10, 1),
      completed: true,
    );
    item = await store.saveItem(item.copyWith(times: [item.times.last]));
    expect(item.usedQuantityBase, 1);
    expect(item.remainingQuantity, 5);
    expect(await store.completionCount(), 0);
    final deleted = await store.deleteItem(item.id!);
    await store.restoreDeletedItem(deleted!);
    expect((await store.loadItems()).single.remainingQuantity, 5);
  });

  test('completed occurrences sort after pending occurrences', () {
    final item = ReminderItem(
      id: 4,
      title: '感冒药',
      iconKey: 'medication',
      startDate: DateTime(2026, 10, 18),
      repeatKind: RepeatKind.daily,
      times: const [
        ReminderTime(id: 8, itemId: 4, minuteOfDay: 480, sortOrder: 0),
        ReminderTime(id: 9, itemId: 4, minuteOfDay: 780, sortOrder: 1),
      ],
    );
    final date = DateTime(2026, 10, 18);
    final group = DayTaskGroup(
      item: item,
      date: date,
      completedKeys: {completionKey(4, 8, date)},
    );

    expect(group.orderedTimes.map((time) => time.id), [9, 8]);
    expect(group.completedCount, 1);
  });

  test('memory store keeps completion after a reload', () async {
    final store = MemoryDailyStore(
      seedItems: [
        ReminderItem(
          title: '维生素 D',
          iconKey: 'vitamin',
          startDate: DateTime(2026, 10, 18),
          repeatKind: RepeatKind.daily,
          times: const [ReminderTime(minuteOfDay: 540, sortOrder: 0)],
        ),
      ],
    );
    final saved = (await store.loadItems()).single;
    final date = DateTime(2026, 10, 18);
    await store.setCompletion(
      itemId: saved.id!,
      reminderTimeId: saved.times.single.id!,
      date: date,
      completed: true,
    );

    final keys = await store.loadCompletionKeys(date, date);
    expect(
      keys,
      contains(completionKey(saved.id!, saved.times.single.id!, date)),
    );
  });

  test('completion timestamps survive reload and deletion undo', () async {
    final date = DateTime(2026, 10, 29);
    final firstCompletion = DateTime(2026, 10, 29, 8);
    final latestCompletion = DateTime(2026, 10, 29, 9);
    final store = MemoryDailyStore(
      seedItems: [
        ReminderItem(
          title: '药片',
          iconKey: 'medication',
          startDate: date,
          repeatKind: RepeatKind.daily,
          times: const [ReminderTime(minuteOfDay: 480, sortOrder: 0)],
        ),
      ],
    );
    final item = (await store.loadItems()).single;
    final key = completionKey(item.id!, item.times.single.id!, date);
    await store.setCompletion(
      itemId: item.id!,
      reminderTimeId: item.times.single.id!,
      date: date,
      completed: true,
      completedAt: firstCompletion,
    );
    await store.setCompletion(
      itemId: item.id!,
      reminderTimeId: item.times.single.id!,
      date: date,
      completed: true,
      completedAt: latestCompletion,
    );
    expect(await store.loadCompletionTimes(date, date), {key: firstCompletion});

    final deleted = await store.deleteItem(item.id!);
    await store.restoreDeletedItem(deleted!);
    expect(await store.loadCompletionTimes(date, date), {key: firstCompletion});
    final tomorrow = date.add(const Duration(days: 1));
    expect(await store.loadCompletionTimes(tomorrow, tomorrow), isEmpty);

    await store.setCompletion(
      itemId: item.id!,
      reminderTimeId: item.times.single.id!,
      date: date,
      completed: false,
    );
    await store.setCompletion(
      itemId: item.id!,
      reminderTimeId: item.times.single.id!,
      date: date,
      completed: true,
      completedAt: latestCompletion,
    );
    expect(await store.loadCompletionTimes(date, date), {
      key: latestCompletion,
    });
  });
}
