import 'dart:async';

enum RepeatKind { daily, weekly, interval }

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
    this.intervalDays = 2,
    this.weekdays = const <int>{},
    required this.times,
    this.stockQuantity,
    this.doseQuantity = 1,
    this.stockUnit = '片',
    this.productionDate,
    this.expiryDate,
    this.usedQuantityBase = 0,
    this.usedQuantity = 0,
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
  final int intervalDays;
  final Set<int> weekdays;
  final List<ReminderTime> times;
  final double? stockQuantity;
  final double doseQuantity;
  final String stockUnit;
  final DateTime? productionDate;
  final DateTime? expiryDate;
  final double usedQuantityBase;
  final double usedQuantity;

  double? get remainingQuantity => stockQuantity == null
      ? null
      : ((stockQuantity! - usedQuantity) * 100).round() / 100;
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
      RepeatKind.interval =>
        (DateTime.utc(day.year, day.month, day.day)
                    .difference(
                      DateTime.utc(
                        startDate.year,
                        startDate.month,
                        startDate.day,
                      ),
                    )
                    .inDays %
                intervalDays) ==
            0,
    };
  }

  String get scheduleLabel {
    if (repeatKind == RepeatKind.daily) return '每天';
    if (repeatKind == RepeatKind.interval) return '每 $intervalDays 天';
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
    int? intervalDays,
    Set<int>? weekdays,
    List<ReminderTime>? times,
    double? stockQuantity,
    bool clearStockQuantity = false,
    double? doseQuantity,
    String? stockUnit,
    DateTime? productionDate,
    bool clearProductionDate = false,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    double? usedQuantityBase,
    double? usedQuantity,
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
      intervalDays: intervalDays ?? this.intervalDays,
      weekdays: weekdays ?? this.weekdays,
      times: times ?? this.times,
      stockQuantity: clearStockQuantity
          ? null
          : (stockQuantity ?? this.stockQuantity),
      doseQuantity: doseQuantity ?? this.doseQuantity,
      stockUnit: stockUnit ?? this.stockUnit,
      productionDate: clearProductionDate
          ? null
          : (productionDate ?? this.productionDate),
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      usedQuantityBase: usedQuantityBase ?? this.usedQuantityBase,
      usedQuantity: usedQuantity ?? this.usedQuantity,
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

class DeletedCompletion {
  const DeletedCompletion({
    required this.reminderTimeId,
    required this.date,
    required this.completedAt,
    this.quantityUsed = 0,
  });

  final int reminderTimeId;
  final DateTime date;
  final DateTime completedAt;
  final double quantityUsed;
}

class DeletedReminder {
  const DeletedReminder({required this.item, required this.completions});

  final ReminderItem item;
  final List<DeletedCompletion> completions;
}

abstract class DailyStore {
  Future<void> initialize();

  Future<List<ReminderItem>> loadItems({bool includeArchived = false});

  Future<ReminderItem> saveItem(ReminderItem item);

  Future<DeletedReminder?> deleteItem(int itemId);

  Future<void> restoreDeletedItem(DeletedReminder deleted);

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
  final Map<String, double> _completions = <String, double>{};
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
        .map(
          (item) => item.copyWith(
            usedQuantity: item.usedQuantityBase + _usedQuantity(item.id!),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<ReminderItem> saveItem(ReminderItem item) async {
    if (item.id == null) {
      final saved = _assignIds(item);
      _items.add(saved);
      return saved.copyWith(usedQuantity: saved.usedQuantityBase);
    }
    final index = _items.indexWhere((entry) => entry.id == item.id);
    var saved = _assignIds(item);
    if (index >= 0) {
      final retainedIds = saved.times
          .map((time) => time.id)
          .whereType<int>()
          .toSet();
      final removedIds = _items[index].times
          .map((time) => time.id)
          .whereType<int>()
          .where((id) => !retainedIds.contains(id))
          .toSet();
      var removedUsage = 0.0;
      _completions.removeWhere((key, quantity) {
        final parts = key.split(':');
        final remove =
            parts.length == 3 &&
            int.tryParse(parts[0]) == item.id &&
            removedIds.contains(int.tryParse(parts[1]));
        if (remove) removedUsage += quantity;
        return remove;
      });
      saved = saved.copyWith(
        usedQuantityBase: _items[index].usedQuantityBase + removedUsage,
      );
    }
    if (index == -1) {
      _items.add(saved);
    } else {
      _items[index] = saved;
    }
    return saved.copyWith(
      usedQuantity: saved.usedQuantityBase + _usedQuantity(saved.id!),
    );
  }

  @override
  Future<DeletedReminder?> deleteItem(int itemId) async {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index == -1) return null;
    final item = _items[index];
    final timeIds = item.times.map((time) => time.id).whereType<int>().toSet();
    final completions = <DeletedCompletion>[];
    for (final key in _completions.keys) {
      final parts = key.split(':');
      if (parts.length != 3 || int.tryParse(parts[0]) != itemId) continue;
      final reminderTimeId = int.tryParse(parts[1]);
      if (reminderTimeId == null || !timeIds.contains(reminderTimeId)) continue;
      completions.add(
        DeletedCompletion(
          reminderTimeId: reminderTimeId,
          date: parseDay(parts[2]),
          completedAt: DateTime.now(),
          quantityUsed: _completions[key] ?? 0,
        ),
      );
    }
    _items.removeWhere((item) => item.id == itemId);
    _completions.removeWhere((key, _) {
      final parts = key.split(':');
      return parts.length > 1 && timeIds.contains(int.tryParse(parts[1]));
    });
    return DeletedReminder(item: item, completions: completions);
  }

  @override
  Future<void> restoreDeletedItem(DeletedReminder deleted) async {
    if (_items.any((item) => item.id == deleted.item.id)) return;
    final restored = _assignIds(deleted.item);
    _items.add(restored);
    for (final completion in deleted.completions) {
      _completions[completionKey(
            restored.id!,
            completion.reminderTimeId,
            completion.date,
          )] =
          completion.quantityUsed;
    }
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
      if (_completions.containsKey(key)) return;
      final item = _items.where((entry) => entry.id == itemId).first;
      _completions[key] = item.stockQuantity == null ? 0 : item.doseQuantity;
    } else {
      _completions.remove(key);
    }
  }

  @override
  Future<Set<String>> loadCompletionKeys(DateTime from, DateTime to) async {
    final start = dayKey(from);
    final end = dayKey(to);
    return _completions.keys.where((key) {
      final date = key.split(':').last;
      return date.compareTo(start) >= 0 && date.compareTo(end) <= 0;
    }).toSet();
  }

  @override
  Future<int> completionCount() async => _completions.length;

  double _usedQuantity(int itemId) => _completions.entries
      .where((entry) => entry.key.startsWith('$itemId:'))
      .fold(0, (sum, entry) => sum + entry.value);
}

class AppRefreshSignal {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;
  void notify() => _controller.add(null);
  Future<void> dispose() => _controller.close();
}
