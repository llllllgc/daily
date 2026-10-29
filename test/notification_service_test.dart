import 'package:daily/services/notification_service.dart';
import 'package:daily/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exact alarm permission selects exact Android scheduling', () {
    expect(
      androidScheduleModeForExactAlarmPermission(true).name,
      'exactAllowWhileIdle',
    );
    expect(
      androidScheduleModeForExactAlarmPermission(false).name,
      'inexactAllowWhileIdle',
    );
  });

  test('test notification payload round-trips action data', () {
    final payload = NotificationPayload(
      itemId: -1,
      reminderTimeId: -1,
      date: DateTime(2026, 10, 19),
      title: 'Daily 测试提醒',
      timeLabel: '09:30',
      snoozeMinutes: 1,
      isTest: true,
    );

    final decoded = NotificationPayload.decode(payload.encode());

    expect(decoded, isNotNull);
    expect(decoded!.itemId, -1);
    expect(decoded.reminderTimeId, -1);
    expect(decoded.timeLabel, '09:30');
    expect(decoded.snoozeMinutes, 1);
    expect(decoded.isTest, isTrue);
  });

  test(
    'complete action marks only the notified occurrence completed',
    () async {
      final date = DateTime(2026, 10, 19);
      final store = MemoryDailyStore(
        seedItems: [
          ReminderItem(
            title: '感冒药',
            iconKey: 'medication',
            startDate: date,
            repeatKind: RepeatKind.daily,
            times: const [
              ReminderTime(minuteOfDay: 8 * 60, sortOrder: 0),
              ReminderTime(minuteOfDay: 20 * 60, sortOrder: 1),
            ],
          ),
        ],
      );
      final item = (await store.loadItems()).single;
      final notifiedTime = item.times.last;
      final payload = NotificationPayload(
        itemId: item.id!,
        reminderTimeId: notifiedTime.id!,
        date: date,
        title: item.title,
        timeLabel: notifiedTime.label,
      );

      final completed = await completeNotificationOccurrence(
        store: store,
        payload: payload,
      );
      final keys = await store.loadCompletionKeys(date, date);

      expect(completed, isTrue);
      expect(keys, contains(completionKey(item.id!, notifiedTime.id!, date)));
      expect(
        keys,
        isNot(contains(completionKey(item.id!, item.times.first.id!, date))),
      );
    },
  );

  test('test notification cannot complete a real occurrence', () async {
    final date = DateTime(2026, 10, 19);
    final store = MemoryDailyStore();
    final payload = NotificationPayload(
      itemId: 1,
      reminderTimeId: 1,
      date: date,
      title: 'Daily 测试提醒',
      timeLabel: '09:30',
      isTest: true,
    );

    final completed = await completeNotificationOccurrence(
      store: store,
      payload: payload,
    );

    expect(completed, isFalse);
    expect(await store.completionCount(), 0);
  });

  test('schedule plan is not truncated at the old 96 notification limit', () {
    final start = DateTime(2026, 10, 20);
    final item = ReminderItem(
      id: 7,
      title: '多次用药',
      iconKey: 'medication',
      startDate: start,
      repeatKind: RepeatKind.daily,
      times: [
        for (var index = 0; index < 12; index++)
          ReminderTime(
            id: 100 + index,
            itemId: 7,
            minuteOfDay: (8 + index) * 60,
            sortOrder: index,
          ),
      ],
    );

    final plan = buildNotificationSchedulePlan(
      items: [item],
      now: DateTime(2026, 10, 20, 7),
    );

    expect(plan.length, greaterThan(96));
    expect(
      plan.any(
        (entry) =>
            dayKey(entry.date) == dayKey(start.add(const Duration(days: 34))),
      ),
      isTrue,
    );
  });

  test('schedule reconciliation preserves snoozed notifications', () {
    final date = DateTime(2026, 10, 20);
    final scheduled = NotificationPayload(
      itemId: 1,
      reminderTimeId: 2,
      date: date,
      title: '维生素 D',
      timeLabel: '09:00',
      kind: NotificationKind.scheduled,
    );
    final snoozed = NotificationPayload(
      itemId: 1,
      reminderTimeId: 2,
      date: date,
      title: '维生素 D',
      timeLabel: '09:00',
      kind: NotificationKind.snoozed,
    );

    final obsolete = obsoleteManagedNotificationIds(
      pending: [
        PendingNotificationSnapshot(id: 10, payload: scheduled.encode()),
        PendingNotificationSnapshot(id: 11, payload: snoozed.encode()),
      ],
      desiredIds: const <int>{},
    );

    expect(obsolete, {10});
  });
}
