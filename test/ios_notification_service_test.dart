import 'package:daily/models.dart';
import 'package:daily/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezoneChannel = MethodChannel('flutter_timezone');
  final calls = <MethodCall>[];
  var pending = <Map<String, Object?>>[];
  var allowed = false;
  late NotificationService service;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    calls.clear();
    pending = [];
    allowed = false;
    service = NotificationService(store: MemoryDailyStore());
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      timezoneChannel,
      (_) async => 'Asia/Shanghai',
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' || 'openAppNotificationSettings' => true,
        'requestPermissions' => allowed,
        'checkPermissions' => {'isEnabled': allowed, 'isAlertEnabled': allowed},
        'pendingNotificationRequests' => pending,
        _ => null,
      };
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(timezoneChannel, null);
  });

  Future<List<ReminderItem>> busySchedule() async {
    final tomorrow = dateOnly(
      tz.TZDateTime.now(tz.local),
    ).add(const Duration(days: 1));
    final store = MemoryDailyStore(
      seedItems: [
        for (var i = 0; i < 4; i++)
          ReminderItem(
            title: '事项 $i',
            iconKey: 'medication',
            startDate: tomorrow,
            endDate: tomorrow.add(const Duration(days: 10)),
            repeatKind: RepeatKind.daily,
            // Deliberately unsorted: the earliest request must win the budget.
            times: const [
              ReminderTime(minuteOfDay: 23 * 60, sortOrder: 0),
              ReminderTime(minuteOfDay: 6 * 60, sortOrder: 1),
              ReminderTime(minuteOfDay: 12 * 60, sortOrder: 2),
            ],
            alertMonthBefore: false,
          ),
      ],
    );
    return store.loadItems();
  }

  test(
    'iOS registers both action categories without asking on startup',
    () async {
      await service.initialize();

      final settings =
          calls.singleWhere((call) => call.method == 'initialize').arguments
              as Map;
      expect(settings['requestAlertPermission'], isFalse);
      expect(settings['requestSoundPermission'], isFalse);
      final categories = settings['notificationCategories'] as List;
      expect(categories, hasLength(2));
      expect(
        (categories.first['actions'] as List).map(
          (action) => action['identifier'],
        ),
        ['complete'],
      );
      expect(
        (categories.last['actions'] as List).map(
          (action) => action['identifier'],
        ),
        ['complete', 'snooze'],
      );
    },
  );

  test('iOS reads actual permission state and opens native settings', () async {
    expect(await service.areNotificationsEnabled(), isFalse);
    expect((await service.health()).notificationsEnabled, isFalse);
    allowed = true;
    expect(await service.requestPermission(), isTrue);
    expect(await service.areNotificationsEnabled(), isTrue);
    await service.openNotificationSettings();

    final request =
        calls
                .singleWhere((call) => call.method == 'requestPermissions')
                .arguments
            as Map;
    expect(request['alert'], isTrue);
    expect(request['sound'], isTrue);
    expect(
      calls.any((call) => call.method == 'openAppNotificationSettings'),
      isTrue,
    );
  });

  test('iOS keeps the earliest 60 requests including cycle alerts', () async {
    await service.sync(await busySchedule());

    final requests = calls
        .where((call) => call.method == 'zonedSchedule')
        .map((call) => call.arguments as Map)
        .toList();
    expect(requests, hasLength(60));
    final dates = requests
        .map(
          (request) => DateTime.parse(request['scheduledDateTime'] as String),
        )
        .toList();
    expect(dates.first.hour, 6);
    for (var i = 1; i < dates.length; i++) {
      expect(dates[i].isBefore(dates[i - 1]), isFalse);
    }
    expect(
      requests.where(
        (request) => (request['body'] as String).contains('还有一周结束'),
      ),
      hasLength(4),
    );
  });

  test(
    'resync preserves snoozes and counts them toward the iOS limit',
    () async {
      final items = await busySchedule();
      final item = items.first;
      pending = [
        for (var i = 0; i < 6; i++)
          {
            'id': 100 + i,
            'payload': NotificationPayload(
              itemId: item.id!,
              reminderTimeId: item.times.first.id!,
              date: item.startDate,
              title: item.title,
              timeLabel: '23:00',
              snoozeMinutes: 10,
              isSnoozed: true,
            ).encode(),
          },
        {'id': 99, 'payload': null},
      ];

      await service.sync(items);

      expect(
        calls.where((call) => call.method == 'zonedSchedule'),
        hasLength(58),
      );
      final cancelled = calls
          .where((call) => call.method == 'cancel')
          .map((call) => call.arguments);
      expect(cancelled, [99]);
    },
  );

  test('resync cancels a snooze after its item is deleted', () async {
    pending = [
      {
        'id': 98,
        'payload': NotificationPayload(
          itemId: 1,
          reminderTimeId: 2,
          date: DateTime(2026, 10, 28),
          title: '已删除事项',
          timeLabel: '09:00',
          snoozeMinutes: 10,
          isSnoozed: true,
        ).encode(),
      },
    ];
    await service.sync([]);

    expect(calls.singleWhere((call) => call.method == 'cancel').arguments, 98);
    expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
  });

  test(
    'iOS snooze uses the action category and remains identifiable',
    () async {
      await NotificationService.scheduleSnooze(
        NotificationPayload(
          itemId: 1,
          reminderTimeId: 2,
          date: DateTime(2026, 10, 28),
          title: '提醒',
          timeLabel: '09:00',
          snoozeMinutes: 10,
        ),
      );

      final request =
          calls.singleWhere((call) => call.method == 'zonedSchedule').arguments
              as Map;
      final payload = NotificationPayload.decode(request['payload'] as String)!;
      expect(payload.isSnoozed, isTrue);
      expect(payload.reminderTimeId, 2);
      expect(
        (request['platformSpecifics'] as Map)['categoryIdentifier'],
        'daily_reminder_with_snooze',
      );
    },
  );
}
