import 'package:daily/services/notification_service.dart';
import 'package:daily/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
