import 'dart:async';

enum RepeatKind { daily, weekly }

enum DayRecordStatus { none, pending, partial, complete, missed }

DayRecordStatus dayRecordStatus({
  required DateTime date,
  required DateTime today,
  required int completed,
  required int total,
}) {
  final day = dateOnly(date);
  final currentDay = dateOnly(today);
  if (total == 0 || day.isAfter(currentDay)) return DayRecordStatus.none;
  if (completed >= total) return DayRecordStatus.complete;
  if (day.isBefore(currentDay)) return DayRecordStatus.missed;
  if (completed > 0) return DayRecordStatus.partial;
  return DayRecordStatus.pending;
}

String dayKey(DateTime value) {
  final day = DateTime(value.year, value.month, value.day);
  return '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

DateTime parseDay(String value) {
  final parsed = DateTime.parse(value);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String completionKey(int itemId, int reminderTimeId, DateTime date) =>
    '$itemId:$reminderTimeId:${dayKey(date)}';

class ReminderTime {
  const ReminderTime({
    this.id,
    this.itemId,
    required this.minuteOfDay,
    required this.sortOrder,
  });

  final int? id;
  final int? itemId;
  final int minuteOfDay;
  final int sortOrder;

  int get hour => minuteOfDay ~/ 60;
  int get minute => minuteOfDay % 60;

  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  ReminderTime copyWith({
    int? id,
    int? itemId,
    int? minuteOfDay,
    int? sortOrder,
  }) {
    return ReminderTime(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      minuteOfDay: minuteOfDay ?? this.minuteOfDay,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class ReminderItem {
  const ReminderItem({
    this.id,
    required this.title,
    required this.iconKey,
    required this.startDate,
    this.endDate,
    required this.repeatKind,
    this.weekdays = const <int>{},
    required this.times,
    this.snoozeMinutes,
    this.alertMonthBefore = true,
    this.alertWeekBefore = true,
    this.archived = false,
    this.createdAt,
  });

  final int? id;
  final String title;
  final String iconKey;
  final DateTime startDate;
  final DateTime? endDate;
  final RepeatKind repeatKind;
  final Set<int> weekdays;
  final List<ReminderTime> times;
  final int? snoozeMinutes;
  final bool alertMonthBefore;
  final bool alertWeekBefore;
  final bool archived;
  final DateTime? createdAt;

  bool get hasEnded =>
      endDate != null && dateOnly(endDate!).isBefore(dateOnly(DateTime.now()));

  bool isScheduledOn(DateTime date) {
    final day = dateOnly(date);
    if (archived || day.isBefore(dateOnly(startDate))) return false;
    if (endDate != null && day.isAfter(dateOnly(endDate!))) return false;
    return switch (repeatKind) {
      RepeatKind.daily => true,
      RepeatKind.weekly => weekdays.contains(day.weekday),
    };
  }

  String get scheduleLabel {
    if (repeatKind == RepeatKind.daily) return '每天';
    const labels = <int, String>{
      1: '周一',
      2: '周二',
      3: '周三',
      4: '周四',
      5: '周五',
      6: '周六',
      7: '周日',
    };
    final ordered = weekdays.toList()..sort();
    return ordered.map((day) => labels[day]).join('、');
  }

  ReminderItem copyWith({
    int? id,
    String? title,
    String? iconKey,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    RepeatKind? repeatKind,
    Set<int>? weekdays,
    List<ReminderTime>? times,
    int? snoozeMinutes,
    bool clearSnooze = false,
    bool? alertMonthBefore,
    bool? alertWeekBefore,
    bool? archived,
    DateTime? createdAt,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      iconKey: iconKey ?? this.iconKey,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      repeatKind: repeatKind ?? this.repeatKind,
      weekdays: weekdays ?? this.weekdays,
      times: times ?? this.times,
      snoozeMinutes: clearSnooze ? null : (snoozeMinutes ?? this.snoozeMinutes),
      alertMonthBefore: alertMonthBefore ?? this.alertMonthBefore,
      alertWeekBefore: alertWeekBefore ?? this.alertWeekBefore,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DayTaskGroup {
  const DayTaskGroup({
    required this.item,
    required this.date,
    required this.completedKeys,
  });

  final ReminderItem item;
  final DateTime date;
  final Set<String> completedKeys;

  List<ReminderTime> get orderedTimes {
    final result = List<ReminderTime>.from(item.times);
    result.sort((a, b) {
      final aDone = isCompleted(a);
      final bDone = isCompleted(b);
      if (aDone != bDone) return aDone ? 1 : -1;
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order != 0 ? order : a.minuteOfDay.compareTo(b.minuteOfDay);
    });
    return result;
  }

  bool isCompleted(ReminderTime time) {
    final itemId = item.id;
    final timeId = time.id;
    if (itemId == null || timeId == null) return false;
    return completedKeys.contains(completionKey(itemId, timeId, date));
  }

  int get completedCount => item.times.where(isCompleted).length;
  bool get allCompleted =>
      item.times.isNotEmpty && completedCount == item.times.length;
}

abstract class DailyStore {
  Future<void> initialize();

  Future<List<ReminderItem>> loadItems({bool includeArchived = false});

  Future<ReminderItem> saveItem(ReminderItem item);

  Future<void> deleteItem(int itemId);

  Future<void> setCompletion({
    required int itemId,
    required int reminderTimeId,
    required DateTime date,
    required bool completed,
  });

  Future<Set<String>> loadCompletionKeys(DateTime from, DateTime to);

  Future<int> completionCount();
}

class MemoryDailyStore implements DailyStore {
  MemoryDailyStore({List<ReminderItem> seedItems = const <ReminderItem>[]})
    : _items = <ReminderItem>[] {
    for (final item in seedItems) {
      _items.add(_assignIds(item));
    }
  }

  final List<ReminderItem> _items;
  final Set<String> _completions = <String>{};
  int _nextItemId = 1;
  int _nextTimeId = 1;

  @override
  Future<void> initialize() async {}

  ReminderItem _assignIds(ReminderItem item) {
    final itemId = item.id ?? _nextItemId++;
    if (itemId >= _nextItemId) _nextItemId = itemId + 1;
    final times = <ReminderTime>[];
    for (final time in item.times) {
      final timeId = time.id ?? _nextTimeId++;
      if (timeId >= _nextTimeId) _nextTimeId = timeId + 1;
      times.add(time.copyWith(id: timeId, itemId: itemId));
    }
    return item.copyWith(id: itemId, times: times);
  }

  @override
  Future<List<ReminderItem>> loadItems({bool includeArchived = false}) async {
    return _items
        .where((item) => includeArchived || !item.archived)
        .toList(growable: false);
  }

  @override
  Future<ReminderItem> saveItem(ReminderItem item) async {
    if (item.id == null) {
      final saved = _assignIds(item);
      _items.add(saved);
      return saved;
    }
    final index = _items.indexWhere((entry) => entry.id == item.id);
    final saved = _assignIds(item);
    if (index == -1) {
      _items.add(saved);
    } else {
      _items[index] = saved;
    }
    return saved;
  }

  @override
  Future<void> deleteItem(int itemId) async {
    final timeIds = _items
        .where((item) => item.id == itemId)
        .expand((item) => item.times)
        .map((time) => time.id)
        .whereType<int>()
        .toSet();
    _items.removeWhere((item) => item.id == itemId);
    _completions.removeWhere((key) {
      final parts = key.split(':');
      return parts.length > 1 && timeIds.contains(int.tryParse(parts[1]));
    });
  }

  @override
  Future<void> setCompletion({
    required int itemId,
    required int reminderTimeId,
    required DateTime date,
    required bool completed,
  }) async {
    final key = completionKey(itemId, reminderTimeId, date);
    if (completed) {
      _completions.add(key);
    } else {
      _completions.remove(key);
    }
  }

  @override
  Future<Set<String>> loadCompletionKeys(DateTime from, DateTime to) async {
    final start = dayKey(from);
    final end = dayKey(to);
    return _completions.where((key) {
      final date = key.split(':').last;
      return date.compareTo(start) >= 0 && date.compareTo(end) <= 0;
    }).toSet();
  }

  @override
  Future<int> completionCount() async => _completions.length;
}

class AppRefreshSignal {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;
  void notify() => _controller.add(null);
  Future<void> dispose() => _controller.close();
}
