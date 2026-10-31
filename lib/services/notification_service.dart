import 'dart:convert';
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
const _reminderCategory = 'daily_reminder';
const _snoozeCategory = 'daily_reminder_with_snooze';
const _notificationActionPortName = 'daily.notification_action_refresh';
const _completionChangedMessage = 'completion_changed';
const _deviceSettingsChannel = MethodChannel('daily/device_settings');
const notificationSchedulingHorizonDays = 35;
const notificationSchedulingLimit = 450;

AndroidScheduleMode androidScheduleModeForExactAlarmPermission(
  bool exactAlarmAllowed,
) => exactAlarmAllowed
    ? AndroidScheduleMode.exactAllowWhileIdle
    : AndroidScheduleMode.inexactAllowWhileIdle;

enum NotificationKind { scheduled, snoozed, cycle, test }

class PlannedReminder {
  const PlannedReminder({
    required this.item,
    required this.time,
    required this.date,
    required this.scheduledAt,
  });

  final ReminderItem item;
  final ReminderTime time;
  final DateTime date;
  final DateTime scheduledAt;

  int get notificationId =>
      NotificationService._notificationId(item.id!, time.id!, date);
}

class PendingNotificationSnapshot {
  const PendingNotificationSnapshot({required this.id, this.payload});

  final int id;
  final String? payload;
}

List<PlannedReminder> buildNotificationSchedulePlan({
  required List<ReminderItem> items,
  required DateTime now,
  int horizonDays = notificationSchedulingHorizonDays,
  int limit = notificationSchedulingLimit,
}) {
  final firstDay = dateOnly(now);
  final plan = <PlannedReminder>[];
  for (var offset = 0; offset < horizonDays; offset++) {
    final date = firstDay.add(Duration(days: offset));
    for (final item in items.where((entry) => entry.isScheduledOn(date))) {
      if (item.id == null) continue;
      for (final time in item.times) {
        if (time.id == null) continue;
        final scheduledAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (!scheduledAt.isAfter(now.add(const Duration(seconds: 5)))) {
          continue;
        }
        plan.add(
          PlannedReminder(
            item: item,
            time: time,
            date: date,
            scheduledAt: scheduledAt,
          ),
        );
      }
    }
  }
  plan.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return plan.take(limit).toList(growable: false);
}

Set<int> obsoleteManagedNotificationIds({
  required List<PendingNotificationSnapshot> pending,
  required Set<int> desiredIds,
}) {
  final result = <int>{};
  for (final request in pending) {
    final payload = NotificationPayload.decode(request.payload);
    if (payload == null ||
        payload.kind == NotificationKind.snoozed ||
        payload.kind == NotificationKind.test) {
      continue;
    }
    if (!desiredIds.contains(request.id)) result.add(request.id);
  }
  return result;
}

class ReminderHealth {
  const ReminderHealth({
    required this.notificationsEnabled,
    required this.exactAlarmAllowed,
    required this.reminderChannelEnabled,
    required this.reminderChannelCanPopUp,
    required this.batteryOptimizationIgnored,
    required this.pendingCount,
    this.lastSyncedAt,
  });

  final bool notificationsEnabled;
  final bool exactAlarmAllowed;
  final bool reminderChannelEnabled;
  final bool reminderChannelCanPopUp;
  final bool batteryOptimizationIgnored;
  final int pendingCount;
  final DateTime? lastSyncedAt;
}

abstract class ReminderScheduler {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> requestExactAlarmPermission();
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
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<bool> areNotificationsEnabled() async => true;

  @override
  Future<ReminderHealth> health() async => const ReminderHealth(
    notificationsEnabled: true,
    exactAlarmAllowed: true,
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
    this.kind = NotificationKind.scheduled,
    this.isTest = false,
    this.isSnoozed = false,
  });

  final int itemId;
  final int reminderTimeId;
  final DateTime date;
  final String title;
  final String timeLabel;
  final int? snoozeMinutes;
  final NotificationKind kind;
  final bool isTest;
  final bool isSnoozed;

  String encode() => jsonEncode(<String, Object?>{
    'itemId': itemId,
    'reminderTimeId': reminderTimeId,
    'date': dayKey(date),
    'title': title,
    'timeLabel': timeLabel,
    'snoozeMinutes': snoozeMinutes,
    'kind': kind.name,
    'isTest': isTest,
    'isSnoozed': isSnoozed,
  });

  static NotificationPayload? decode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final map = jsonDecode(value) as Map<String, dynamic>;
      final isTest = map['isTest'] as bool? ?? false;
      final kindName = map['kind'] as String?;
      final kind = NotificationKind.values.where(
        (entry) => entry.name == kindName,
      );
      return NotificationPayload(
        itemId: map['itemId'] as int,
        reminderTimeId: map['reminderTimeId'] as int,
        date: parseDay(map['date'] as String),
        title: map['title'] as String,
        timeLabel: map['timeLabel'] as String,
        snoozeMinutes: map['snoozeMinutes'] as int?,
        kind: kind.isEmpty
            ? (isTest
                  ? NotificationKind.test
                  : (map['isSnoozed'] == true
                        ? NotificationKind.snoozed
                        : NotificationKind.scheduled))
            : kind.first,
        isTest: isTest,
        isSnoozed:
            (map['isSnoozed'] as bool? ?? false) ||
            kindName == NotificationKind.snoozed.name,
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

typedef _ScheduledNotification = ({
  int id,
  String title,
  String body,
  tz.TZDateTime date,
  NotificationDetails details,
  String? payload,
});

class NotificationService implements ReminderScheduler {
  NotificationService({required this.store, this.refreshSignal});

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final DailyStore store;
  final AppRefreshSignal? refreshSignal;
  ReceivePort? _notificationActionPort;
  bool _initialized = false;
  DateTime? _lastSyncedAt;
  Future<void> _syncQueue = Future<void>.value();

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get _isSupported => !kIsWeb && (_isAndroid || _isIOS);

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

  static final _initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _reminderCategory,
          actions: [DarwinNotificationAction.plain(_completeAction, '完成')],
        ),
        DarwinNotificationCategory(
          _snoozeCategory,
          actions: [
            DarwinNotificationAction.plain(_completeAction, '完成'),
            DarwinNotificationAction.plain(_snoozeAction, '稍后提醒'),
          ],
        ),
      ],
    ),
  );

  static NotificationDetails _reminderDetails({required bool allowSnooze}) {
    return NotificationDetails(
      iOS: DarwinNotificationDetails(
        categoryIdentifier: allowSnooze ? _snoozeCategory : _reminderCategory,
        threadIdentifier: _reminderChannel,
      ),
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
    iOS: DarwinNotificationDetails(threadIdentifier: _cycleChannel),
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
    if (_initialized || !_isSupported) return;
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
    if (!_isSupported) return true;
    await initialize();
    if (_isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb || !_isAndroid) return true;
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestExactAlarmsPermission() ??
        false;
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    if (!_isSupported) return true;
    await initialize();
    if (_isIOS) {
      final permissions = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return permissions?.isEnabled ?? false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
  }

  @override
  Future<ReminderHealth> health() async {
    if (!_isSupported) {
      return ReminderHealth(
        notificationsEnabled: true,
        exactAlarmAllowed: true,
        reminderChannelEnabled: true,
        reminderChannelCanPopUp: true,
        batteryOptimizationIgnored: true,
        pendingCount: 0,
        lastSyncedAt: _lastSyncedAt,
      );
    }
    await initialize();
    if (_isIOS) {
      final permissions = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      final pending = await _plugin.pendingNotificationRequests();
      return ReminderHealth(
        notificationsEnabled: permissions?.isEnabled ?? false,
        exactAlarmAllowed: true,
        reminderChannelEnabled: permissions?.isEnabled ?? false,
        reminderChannelCanPopUp: permissions?.isAlertEnabled ?? false,
        batteryOptimizationIgnored: true,
        pendingCount: pending.length,
        lastSyncedAt: _lastSyncedAt,
      );
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final notificationsEnabled =
        await android?.areNotificationsEnabled() ?? false;
    final exactAlarmAllowed =
        await android?.canScheduleExactNotifications() ?? false;
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
      exactAlarmAllowed: exactAlarmAllowed,
      reminderChannelEnabled: reminderChannel != null && importance > 0,
      reminderChannelCanPopUp: importance >= Importance.high.value,
      batteryOptimizationIgnored: batteryOptimizationIgnored,
      pendingCount: pending.length,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  @override
  Future<void> openNotificationSettings() async {
    if (!_isSupported) return;
    await initialize();
    if (_isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
      return;
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.openAppNotificationSettings();
  }

  @override
  Future<void> openBatterySettings() async {
    if (kIsWeb || !_isAndroid) return;
    try {
      await _deviceSettingsChannel.invokeMethod<void>('openBatterySettings');
    } on PlatformException {
      return;
    }
  }

  @override
  Future<void> sync(List<ReminderItem> items) {
    _syncQueue = _syncQueue.catchError((Object _) {}).then((_) => _sync(items));
    return _syncQueue;
  }

  Future<void> _sync(List<ReminderItem> items) async {
    if (!_isSupported) return;
    await initialize();
    if (_isIOS) {
      await _syncIOS(items);
      return;
    }
    final now = tz.TZDateTime.now(tz.local);
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exactAlarmAllowed =
        await android?.canScheduleExactNotifications() ?? false;
    final androidScheduleMode = androidScheduleModeForExactAlarmPermission(
      exactAlarmAllowed,
    );
    final localNow = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
    final cyclePlan = _buildCycleAlertPlan(items, now);
    final reminderLimit = (notificationSchedulingLimit - cyclePlan.length)
        .clamp(0, notificationSchedulingLimit);
    final reminderPlan = buildNotificationSchedulePlan(
      items: items,
      now: localNow,
      limit: reminderLimit,
    );
    final desiredIds = <int>{
      ...reminderPlan.map((entry) => entry.notificationId),
      ...cyclePlan.map((entry) => entry.id),
    };
    final pending = await _plugin.pendingNotificationRequests();
    final obsoleteIds = obsoleteManagedNotificationIds(
      pending: [
        for (final request in pending)
          PendingNotificationSnapshot(id: request.id, payload: request.payload),
      ],
      desiredIds: desiredIds,
    );
    for (final id in obsoleteIds) {
      await _plugin.cancel(id: id);
    }

    for (final entry in reminderPlan) {
      final item = entry.item;
      final time = entry.time;
      final scheduledDate = tz.TZDateTime(
        tz.local,
        entry.date.year,
        entry.date.month,
        entry.date.day,
        time.hour,
        time.minute,
      );
      final payload = NotificationPayload(
        itemId: item.id!,
        reminderTimeId: time.id!,
        date: entry.date,
        title: item.title,
        timeLabel: time.label,
        snoozeMinutes: item.snoozeMinutes,
      );
      await _plugin.zonedSchedule(
        id: entry.notificationId,
        title: item.title,
        body: item.times.length == 1
            ? '现在可以完成这件事了'
            : '第 ${time.sortOrder + 1} 次 · ${time.label}',
        scheduledDate: scheduledDate,
        notificationDetails: _reminderDetails(
          allowSnooze: item.snoozeMinutes != null,
        ),
        androidScheduleMode: androidScheduleMode,
        payload: payload.encode(),
      );
    }

    for (final entry in cyclePlan) {
      await _plugin.zonedSchedule(
        id: entry.id,
        title: entry.item.title,
        body: '${entry.label} · 只作提醒，不会替你更改事项',
        scheduledDate: entry.scheduledDate,
        notificationDetails: _cycleDetails,
        androidScheduleMode: androidScheduleMode,
        payload: NotificationPayload(
          itemId: entry.item.id!,
          reminderTimeId: -1,
          date: entry.scheduledDate,
          title: entry.item.title,
          timeLabel: '09:00',
          kind: NotificationKind.cycle,
        ).encode(),
      );
    }
    _lastSyncedAt = DateTime.now();
  }

  List<({int id, ReminderItem item, String label, tz.TZDateTime scheduledDate})>
  _buildCycleAlertPlan(List<ReminderItem> items, tz.TZDateTime now) {
    final plan =
        <
          ({
            int id,
            ReminderItem item,
            String label,
            tz.TZDateTime scheduledDate,
          })
        >[];
    for (final item in items) {
      final end = item.endDate;
      final itemId = item.id;
      if (end == null || itemId == null) continue;
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
        plan.add((
          id: _cycleNotificationId(itemId, salt),
          item: item,
          label: label,
          scheduledDate: scheduledDate,
        ));
      }
    }
    plan.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return plan.take(notificationSchedulingLimit).toList(growable: false);
  }

  Future<void> _syncIOS(List<ReminderItem> items) async {
    if (!_isSupported) return;
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    var snoozedCount = 0;
    for (final notification in pending) {
      final payload = NotificationPayload.decode(notification.payload);
      final keepSnooze =
          payload != null &&
          payload.isSnoozed &&
          (payload.isTest ||
              items.any(
                (item) =>
                    item.id == payload.itemId &&
                    item.isScheduledOn(payload.date) &&
                    item.times.any((time) => time.id == payload.reminderTimeId),
              ));
      if (keepSnooze) {
        snoozedCount++;
      } else {
        await _plugin.cancel(id: notification.id);
      }
    }

    final now = tz.TZDateTime.now(tz.local);
    final firstDay = DateTime(now.year, now.month, now.day);
    final schedule = <_ScheduledNotification>[];
    for (var offset = 0; offset <= 30; offset++) {
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
          schedule.add((
            id: _notificationId(itemId, timeId, date),
            title: item.title,
            body: item.times.length == 1
                ? '现在可以完成这件事了'
                : '第 ${time.sortOrder + 1} 次 · ${time.label}',
            date: scheduledDate,
            details: _reminderDetails(allowSnooze: item.snoozeMinutes != null),
            payload: payload.encode(),
          ));
        }
      }
    }

    for (final item in items) {
      schedule.addAll(_iosCycleAlerts(item, now));
    }
    schedule.sort((a, b) => a.date.compareTo(b.date));
    // iOS retains at most 64 pending requests. Leave room for snoozes and
    // include cycle alerts in the same budget so they cannot evict reminders.
    final limit = _isIOS ? (64 - snoozedCount).clamp(0, 60) : 96;
    for (final notification in schedule.take(limit)) {
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: notification.date,
        notificationDetails: notification.details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: notification.payload,
      );
    }
    _lastSyncedAt = DateTime.now();
  }

  Iterable<_ScheduledNotification> _iosCycleAlerts(
    ReminderItem item,
    tz.TZDateTime now,
  ) sync* {
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
      yield (
        id: _cycleNotificationId(itemId, salt),
        title: item.title,
        body: '$label · 只作提醒，不会替你更改事项',
        date: scheduledDate,
        details: _cycleDetails,
        payload: null,
      );
    }
  }

  @override
  Future<void> showTestNotification() async {
    if (!_isSupported) return;
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
      kind: NotificationKind.test,
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
    if (!_isSupported || payload.snoozeMinutes == null) return;
    await _configureTimezone();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(settings: _initializationSettings);
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exactAlarmAllowed =
        await android?.canScheduleExactNotifications() ?? false;
    final when = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(minutes: payload.snoozeMinutes!));
    final snoozedPayload = NotificationPayload(
      itemId: payload.itemId,
      reminderTimeId: payload.reminderTimeId,
      date: payload.date,
      title: payload.title,
      timeLabel: payload.timeLabel,
      snoozeMinutes: payload.snoozeMinutes,
      kind: NotificationKind.snoozed,
      isTest: payload.isTest,
      isSnoozed: true,
    );
    await plugin.zonedSchedule(
      id:
          1800000000 +
          DateTime.now().millisecondsSinceEpoch.remainder(100000000),
      title: payload.title,
      body: '稍后提醒 · ${payload.timeLabel}',
      scheduledDate: when,
      notificationDetails: _reminderDetails(allowSnooze: true),
      androidScheduleMode: androidScheduleModeForExactAlarmPermission(
        exactAlarmAllowed,
      ),
      payload: snoozedPayload.encode(),
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
    return 1 +
        (itemId * 1000003 + timeId * 9176 + dateNumber).remainder(1499999998);
  }

  static int _cycleNotificationId(int itemId, int salt) =>
      1600000000 + (itemId * 37 + salt).remainder(100000000);

  static DateTime _monthBefore(DateTime date) {
    final previousMonth = date.month == 1 ? 12 : date.month - 1;
    final year = date.month == 1 ? date.year - 1 : date.year;
    final lastDay = DateTime(year, previousMonth + 1, 0).day;
    return DateTime(year, previousMonth, date.day.clamp(1, lastDay));
  }
}
