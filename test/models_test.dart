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
}
