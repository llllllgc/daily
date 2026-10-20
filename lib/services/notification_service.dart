import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/daily_database.dart';
import '../models.dart';

const _completeAction = 'complete';
const _snoozeAction = 'snooze';
const _reminderChannel = 'daily_reminders';
const _cycleChannel = 'daily_cycle_alerts';
const _notificationActionPortName = 'daily.notification_action_refresh';
const _completionChangedMessage = 'completion_changed';
const _deviceSettingsChannel = MethodChannel('daily/device_settings');

class ReminderHealth {
  const ReminderHealth({
    required this.notificationsEnabled,
    required this.reminderChannelEnabled,
    required this.reminderChannelCanPopUp,
    required this.batteryOptimizationIgnored,
    required this.pendingCount,
    this.lastSyncedAt,
  });

  final bool notificationsEnabled;
  final bool reminderChannelEnabled;
  final bool reminderChannelCanPopUp;
  final bool batteryOptimizationIgnored;
  final int pendingCount;
  final DateTime? lastSyncedAt;
}

abstract class ReminderScheduler {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> areNotificationsEnabled();
  Future<ReminderHealth> health();
  Future<void> openNotificationSettings();
  Future<void> openBatterySettings();
  Future<void> sync(List<ReminderItem> items);
  Future<void> showTestNotification();
}

class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> areNotificationsEnabled() async => true;

  @override
  Future<ReminderHealth> health() async => const ReminderHealth(
    notificationsEnabled: true,
    reminderChannelEnabled: true,
    reminderChannelCanPopUp: true,
    batteryOptimizationIgnored: true,
    pendingCount: 0,
  );

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> openBatterySettings() async {}

  @override
  Future<void> sync(List<ReminderItem> items) async {}

  @override
  Future<void> showTestNotification() async {}
}

class NotificationPayload {
  const NotificationPayload({
    required this.itemId,
    required this.reminderTimeId,
    required this.date,
    required this.title,
    required this.timeLabel,
    this.snoozeMinutes,
    this.isTest = false,
  });

  final int itemId;
  final int reminderTimeId;
  final DateTime date;
  final String title;
  final String timeLabel;
  final int? snoozeMinutes;
  final bool isTest;

  String encode() => jsonEncode(<String, Object?>{
    'itemId': itemId,
    'reminderTimeId': reminderTimeId,
    'date': dayKey(date),
    'title': title,
    'timeLabel': timeLabel,
    'snoozeMinutes': snoozeMinutes,
    'isTest': isTest,
  });

  static NotificationPayload? decode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final map = jsonDecode(value) as Map<String, dynamic>;
      return NotificationPayload(
        itemId: map['itemId'] as int,
        reminderTimeId: map['reminderTimeId'] as int,
        date: parseDay(map['date'] as String),
        title: map['title'] as String,
        timeLabel: map['timeLabel'] as String,
        snoozeMinutes: map['snoozeMinutes'] as int?,
        isTest: map['isTest'] as bool? ?? false,
      );
    } on Object {
      return null;
    }
  }
}

Future<bool> completeNotificationOccurrence({
  required DailyStore store,
  required NotificationPayload payload,
}) async {
  if (payload.isTest || payload.itemId <= 0 || payload.reminderTimeId <= 0) {
    return false;
  }
  await store.setCompletion(
    itemId: payload.itemId,
    reminderTimeId: payload.reminderTimeId,
    date: payload.date,
    completed: true,
  );
  return true;
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final payload = NotificationPayload.decode(response.payload);
  if (payload == null) return;

  if (response.actionId == _completeAction && !payload.isTest) {
    final store = SqliteDailyStore();
    await store.initialize();
    final completed = await completeNotificationOccurrence(
      store: store,
      payload: payload,
    );
    if (completed) {
      IsolateNameServer.lookupPortByName(
        _notificationActionPortName,
      )?.send(_completionChangedMessage);
    }
  } else if (response.actionId == _snoozeAction &&
      payload.snoozeMinutes != null) {
    await NotificationService.scheduleSnooze(payload);
  }
}

class NotificationService implements ReminderScheduler {
  NotificationService({required this.store, this.refreshSignal});

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final DailyStore store;
  final AppRefreshSignal? refreshSignal;
  ReceivePort? _notificationActionPort;
  bool _initialized = false;
  DateTime? _lastSyncedAt;

  static const _reminderChannelSpec = AndroidNotificationChannel(
    _reminderChannel,
    '事项提醒',
    description: '按事项设定的时间提醒，并提供完成与稍后提醒操作',
    importance: Importance.max,
  );

  static const _cycleChannelSpec = AndroidNotificationChannel(
    _cycleChannel,
    '周期结束提醒',
    description: '在事项周期结束前一个月或一周提示',
    importance: Importance.high,
  );

  static const _initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  static NotificationDetails _reminderDetails({required bool allowSnooze}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _reminderChannel,
        '事项提醒',
        channelDescription: '按事项设定的时间提醒，并提供完成与稍后提醒操作',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            _completeAction,
            '完成',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          if (allowSnooze)
            const AndroidNotificationAction(
              _snoozeAction,
              '稍后提醒',
              showsUserInterface: false,
              cancelNotification: true,
            ),
        ],
      ),
    );
  }

  static const _cycleDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _cycleChannel,
      '周期结束提醒',
      channelDescription: '在事项周期结束前一个月或一周提示',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
  );

  @override
  Future<void> initialize() async {
    if (_initialized || kIsWeb || !Platform.isAndroid) return;
    _registerNotificationActionPort();
    await _configureTimezone();
    await _plugin.initialize(
      settings: _initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_reminderChannelSpec);
    await android?.createNotificationChannel(_cycleChannelSpec);
    _initialized = true;
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final payload = NotificationPayload.decode(response.payload);
    if (payload == null) return;
    if (response.actionId == _completeAction && !payload.isTest) {
      final completed = await completeNotificationOccurrence(
        store: store,
        payload: payload,
      );
      if (completed) refreshSignal?.notify();
    } else if (response.actionId == _snoozeAction &&
        payload.snoozeMinutes != null) {
      await scheduleSnooze(payload);
    }
  }

  void _registerNotificationActionPort() {
    if (refreshSignal == null || _notificationActionPort != null) return;
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_notificationActionPortName);
    final registered = IsolateNameServer.registerPortWithName(
      port.sendPort,
      _notificationActionPortName,
    );
    if (!registered) {
      port.close();
      return;
    }
    port.listen((message) {
      if (message == _completionChangedMessage) refreshSignal?.notify();
    });
    _notificationActionPort = port;
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
  }

  @override
  Future<ReminderHealth> health() async {
    if (kIsWeb || !Platform.isAndroid) {
      return ReminderHealth(
        notificationsEnabled: true,
        reminderChannelEnabled: true,
        reminderChannelCanPopUp: true,
        batteryOptimizationIgnored: true,
        pendingCount: 0,
        lastSyncedAt: _lastSyncedAt,
      );
    }
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final notificationsEnabled =
        await android?.areNotificationsEnabled() ?? false;
    final channels = await android?.getNotificationChannels() ?? const [];
    AndroidNotificationChannel? reminderChannel;
    for (final channel in channels) {
      if (channel.id == _reminderChannel) {
        reminderChannel = channel;
        break;
      }
    }
    final pending = await _plugin.pendingNotificationRequests();
    var batteryOptimizationIgnored = true;
    try {
      batteryOptimizationIgnored =
          await _deviceSettingsChannel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } on PlatformException {
      batteryOptimizationIgnored = true;
    }
    final importance = reminderChannel?.importance.value ?? 0;
    return ReminderHealth(
      notificationsEnabled: notificationsEnabled,
      reminderChannelEnabled: reminderChannel != null && importance > 0,
      reminderChannelCanPopUp: importance >= Importance.high.value,
      batteryOptimizationIgnored: batteryOptimizationIgnored,
      pendingCount: pending.length,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  @override
  Future<void> openNotificationSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.openAppNotificationSettings();
  }

  @override
  Future<void> openBatterySettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _deviceSettingsChannel.invokeMethod<void>('openBatterySettings');
    } on PlatformException {
      return;
    }
  }

  @override
  Future<void> sync(List<ReminderItem> items) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await initialize();
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    final firstDay = DateTime(now.year, now.month, now.day);
    var scheduledCount = 0;
    for (var offset = 0; offset <= 30 && scheduledCount < 96; offset++) {
      final date = firstDay.add(Duration(days: offset));
      for (final item in items.where((entry) => entry.isScheduledOn(date))) {
        final itemId = item.id;
        if (itemId == null) continue;
        for (final time in item.times) {
          final timeId = time.id;
          if (timeId == null) continue;
          final scheduledDate = tz.TZDateTime(
            tz.local,
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          if (!scheduledDate.isAfter(now.add(const Duration(seconds: 5)))) {
            continue;
          }
          final payload = NotificationPayload(
            itemId: itemId,
            reminderTimeId: timeId,
            date: date,
            title: item.title,
            timeLabel: time.label,
            snoozeMinutes: item.snoozeMinutes,
          );
          await _plugin.zonedSchedule(
            id: _notificationId(itemId, timeId, date),
            title: item.title,
            body: item.times.length == 1
                ? '现在可以完成这件事了'
                : '第 ${time.sortOrder + 1} 次 · ${time.label}',
            scheduledDate: scheduledDate,
            notificationDetails: _reminderDetails(
              allowSnooze: item.snoozeMinutes != null,
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: payload.encode(),
          );
          scheduledCount++;
          if (scheduledCount >= 96) break;
        }
        if (scheduledCount >= 96) break;
      }
    }

    for (final item in items) {
      await _scheduleCycleAlerts(item, now);
    }
    _lastSyncedAt = DateTime.now();
  }

  Future<void> _scheduleCycleAlerts(
    ReminderItem item,
    tz.TZDateTime now,
  ) async {
    final end = item.endDate;
    final itemId = item.id;
    if (end == null || itemId == null) return;
    final alerts = <(DateTime, String, int)>[];
    if (item.alertMonthBefore) {
      alerts.add((_monthBefore(end), '还有一个月结束', 31));
    }
    if (item.alertWeekBefore) {
      alerts.add((end.subtract(const Duration(days: 7)), '还有一周结束', 7));
    }
    for (final (date, label, salt) in alerts) {
      final scheduledDate = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        9,
      );
      if (!scheduledDate.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: _cycleNotificationId(itemId, salt),
        title: item.title,
        body: '$label · 只作提醒，不会替你更改事项',
        scheduledDate: scheduledDate,
        notificationDetails: _cycleDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> showTestNotification() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await initialize();
    final now = DateTime.now();
    final payload = NotificationPayload(
      itemId: -1,
      reminderTimeId: -1,
      date: now,
      title: 'Daily 测试提醒',
      timeLabel:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      snoozeMinutes: 1,
      isTest: true,
    );
    await _plugin.show(
      id: 2147000001,
      title: 'Daily 测试提醒',
      body: '可以测试“完成”和“稍后提醒”两个按钮',
      notificationDetails: _reminderDetails(allowSnooze: true),
      payload: payload.encode(),
    );
  }

  static Future<void> scheduleSnooze(NotificationPayload payload) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _configureTimezone();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(settings: _initializationSettings);
    final when = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(minutes: payload.snoozeMinutes!));
    await plugin.zonedSchedule(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147000000),
      title: payload.title,
      body: '稍后提醒 · ${payload.timeLabel}',
      scheduledDate: when,
      notificationDetails: _reminderDetails(allowSnooze: true),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload.encode(),
    );
  }

  static Future<void> _configureTimezone() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Object {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    }
  }

  static int _notificationId(int itemId, int timeId, DateTime date) {
    final dateNumber = date.year * 10000 + date.month * 100 + date.day;
    return (itemId * 1000003 + timeId * 9176 + dateNumber).remainder(
      2147000000,
    );
  }

  static int _cycleNotificationId(int itemId, int salt) =>
      (2000000000 + itemId * 37 + salt).remainder(2147000000);

  static DateTime _monthBefore(DateTime date) {
    final previousMonth = date.month == 1 ? 12 : date.month - 1;
    final year = date.month == 1 ? date.year - 1 : date.year;
    final lastDay = DateTime(year, previousMonth + 1, 0).day;
    return DateTime(year, previousMonth, date.day.clamp(1, lastDay));
  }
}
