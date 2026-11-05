part of 'models.dart';

enum OccurrenceStatus {
  pending('待完成'),
  completed('已完成'),
  missed('漏做'),
  skipped('已跳过'),
  paused('暂停');

  const OccurrenceStatus(this.label);
  final String label;
}

Map<String, Object?> itemToJson(ReminderItem item) => {
  'id': item.id,
  'title': item.title,
  'icon': item.iconKey,
  'note': item.note,
  'start': dayKey(item.startDate),
  'end': item.endDate == null ? null : dayKey(item.endDate!),
  'repeat': item.repeatKind.name,
  'interval': item.intervalDays,
  'weekdays': item.weekdays.toList()..sort(),
  'times': [
    for (final time in item.times)
      {'id': time.id, 'minute': time.minuteOfDay, 'order': time.sortOrder},
  ],
  'stock': item.stockQuantity,
  'dose': item.doseQuantity,
  'unit': item.stockUnit,
  'production': item.productionDate == null
      ? null
      : dayKey(item.productionDate!),
  'expiry': item.expiryDate == null ? null : dayKey(item.expiryDate!),
  'usedBase': item.usedQuantityBase,
  'used': item.usedQuantity,
  'snooze': item.snoozeMinutes,
  'alertMonth': item.alertMonthBefore,
  'alertWeek': item.alertWeekBefore,
  'archived': item.archived,
  'created': item.createdAt?.toIso8601String(),
};

ReminderItem itemFromJson(Map<String, Object?> json) => ReminderItem(
  id: json['id'] as int?,
  title: json['title'] as String,
  iconKey: json['icon'] as String,
  note: json['note'] as String? ?? '',
  startDate: parseDay(json['start'] as String),
  endDate: json['end'] == null ? null : parseDay(json['end'] as String),
  repeatKind: RepeatKind.values.byName(json['repeat'] as String),
  intervalDays: json['interval'] as int,
  weekdays: (json['weekdays'] as List).cast<int>().toSet(),
  times: [
    for (final raw in json['times'] as List)
      ReminderTime(
        id: (raw as Map)['id'] as int?,
        itemId: json['id'] as int?,
        minuteOfDay: raw['minute'] as int,
        sortOrder: raw['order'] as int,
      ),
  ],
  stockQuantity: (json['stock'] as num?)?.toDouble(),
  doseQuantity: (json['dose'] as num).toDouble(),
  stockUnit: json['unit'] as String,
  productionDate: json['production'] == null
      ? null
      : parseDay(json['production'] as String),
  expiryDate: json['expiry'] == null
      ? null
      : parseDay(json['expiry'] as String),
  usedQuantityBase: (json['usedBase'] as num?)?.toDouble() ?? 0,
  usedQuantity: (json['used'] as num?)?.toDouble() ?? 0,
  snoozeMinutes: json['snooze'] as int?,
  alertMonthBefore: json['alertMonth'] as bool,
  alertWeekBefore: json['alertWeek'] as bool,
  archived: json['archived'] as bool,
  createdAt: json['created'] == null
      ? null
      : DateTime.parse(json['created'] as String),
);

/// Versions have inclusive effective dates. A new version never rewrites an older day.
Map<String, Map<String, Object?>> planVersionChanges(
  Map<String, Map<String, Object?>> existing,
  ReminderItem? old,
  ReminderItem saved, {
  DateTime? now,
}) {
  final changes = <String, Map<String, Object?>>{};
  final id = saved.id!;
  if (!existing.values.any((entry) => (entry['item'] as Map)['id'] == id)) {
    final initial = old ?? saved;
    final today = dateOnly(now ?? DateTime.now());
    final effective = dayKey(
      initial.startDate.isBefore(today) ? initial.startDate : today,
    );
    changes['$id:$effective'] = {
      'from': effective,
      'item': itemToJson(initial),
    };
  }
  if (old != null) {
    final effective = dayKey(now ?? DateTime.now());
    changes['$id:$effective'] = {'from': effective, 'item': itemToJson(saved)};
  }
  return changes;
}

class OccurrenceRecord {
  const OccurrenceRecord({
    required this.item,
    required this.time,
    required this.date,
    required this.status,
    required this.changedAt,
    this.note = '',
    this.quantityUsed = 0,
  });
  final ReminderItem item;
  final ReminderTime time;
  final DateTime date;
  final OccurrenceStatus status;
  final DateTime changedAt;
  final String note;
  final double quantityUsed;
  String get key => completionKey(item.id!, time.id!, date);
  DateTime get scheduledAt =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
  Map<String, Object?> toJson() => {
    'item': itemToJson(item),
    'timeId': time.id,
    'minute': time.minuteOfDay,
    'order': time.sortOrder,
    'date': dayKey(date),
    'status': status.name,
    'changed': changedAt.toIso8601String(),
    'note': note,
    'quantity': quantityUsed,
  };
  factory OccurrenceRecord.fromJson(Map<String, Object?> json) =>
      OccurrenceRecord(
        item: itemFromJson(Map<String, Object?>.from(json['item'] as Map)),
        time: ReminderTime(
          id: json['timeId'] as int,
          itemId: (json['item'] as Map)['id'] as int,
          minuteOfDay: json['minute'] as int,
          sortOrder: json['order'] as int,
        ),
        date: parseDay(json['date'] as String),
        status: OccurrenceStatus.values.byName(json['status'] as String),
        changedAt: DateTime.parse(json['changed'] as String),
        note: json['note'] as String? ?? '',
        quantityUsed: (json['quantity'] as num?)?.toDouble() ?? 0,
      );
  OccurrenceRecord copyWith({
    OccurrenceStatus? status,
    String? note,
    int? minute,
    DateTime? changedAt,
    double? quantityUsed,
  }) => OccurrenceRecord(
    item: item,
    time: time.copyWith(minuteOfDay: minute),
    date: date,
    status: status ?? this.status,
    changedAt: changedAt ?? this.changedAt,
    note: note ?? this.note,
    quantityUsed: quantityUsed ?? this.quantityUsed,
  );
}

bool pauseCoversDate(Map<String, Object?> pause, int itemId, DateTime date) {
  final day = dayKey(date);
  final resumed = pause['resumedOn'] as String?;
  return pause['itemId'] == itemId &&
      (pause['from'] as String).compareTo(day) <= 0 &&
      (pause['to'] as String).compareTo(day) >= 0 &&
      (resumed == null || day.compareTo(resumed) < 0);
}

class DailyHistory {
  DailyHistory(this.store);
  final DailyStore store;

  Future<void> ensureVersions() async {
    final versions = await store.loadJournal('versions');
    final changes = <String, Map<String, Object?>>{};
    for (final item in await store.loadItems(includeArchived: true)) {
      changes.addAll(planVersionChanges(versions, null, item));
    }
    if (changes.isNotEmpty) await store.writeJournal('versions', changes);
  }

  ReminderItem? _versionFor(
    Iterable<Map<String, Object?>> versions,
    int id,
    DateTime date,
  ) {
    Map<String, Object?>? best;
    final day = dayKey(date);
    for (final entry in versions) {
      if ((entry['item'] as Map)['id'] != id ||
          (entry['from'] as String).compareTo(day) > 0) {
        continue;
      }
      if (best == null ||
          (entry['from'] as String).compareTo(best['from'] as String) > 0) {
        best = entry;
      }
    }
    return best == null
        ? null
        : itemFromJson(Map<String, Object?>.from(best['item'] as Map));
  }

  bool _paused(Iterable<Map<String, Object?>> pauses, int id, DateTime date) =>
      pauses.any((p) => pauseCoversDate(p, id, date));

  Future<void> reconcile({DateTime? now}) async {
    await ensureVersions();
    final today = dateOnly(now ?? DateTime.now());
    final versions = await store.loadJournal('versions');
    if (versions.isEmpty) return;
    final meta = await store.loadJournal('meta');
    final previous = meta['reconciled']?['through'] as String?;
    final earliest = versions.values
        .map((entry) => entry['from'] as String)
        .reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    var from = previous == null
        ? parseDay(earliest)
        : parseDay(previous).add(const Duration(days: 1));
    if (!from.isBefore(today)) return;
    final records = await store.loadJournal(
      'records',
      from: from,
      to: today.subtract(const Duration(days: 1)),
    );
    final stale = <String, Map<String, Object?>>{};
    for (final entry in records.entries) {
      final record = OccurrenceRecord.fromJson(entry.value);
      if (record.status == OccurrenceStatus.pending &&
          record.date.isBefore(today)) {
        stale[entry.key] = record
            .copyWith(
              status: OccurrenceStatus.missed,
              changedAt: DateTime(
                record.date.year,
                record.date.month,
                record.date.day + 1,
              ),
            )
            .toJson();
      }
    }
    if (stale.isNotEmpty) {
      await store.writeJournal('records', stale, onlyIfPending: true);
      records.addAll(stale);
    }
    final pauses = await store.loadJournal('pauses');
    final completions = await store.loadCompletionTimes(from, today);
    final ids = versions.values
        .map((entry) => (entry['item'] as Map)['id'] as int)
        .toSet();
    final pending = <String, Map<String, Object?>>{};
    for (
      ;
      from.isBefore(today);
      from = DateTime(from.year, from.month, from.day + 1)
    ) {
      for (final id in ids) {
        final item = _versionFor(versions.values, id, from);
        if (item == null || !item.isScheduledOn(from)) continue;
        for (final time in item.times) {
          final key = completionKey(id, time.id!, from);
          final existing = records[key];
          if (existing != null) {
            final record = OccurrenceRecord.fromJson(existing);
            if (record.status == OccurrenceStatus.pending) {
              pending[key] = record
                  .copyWith(
                    status: OccurrenceStatus.missed,
                    changedAt: DateTime(from.year, from.month, from.day + 1),
                  )
                  .toJson();
            }
            continue;
          }
          final completedAt = completions[key];
          final record = OccurrenceRecord(
            item: item,
            time: time,
            date: from,
            status: completedAt != null
                ? OccurrenceStatus.completed
                : _paused(pauses.values, id, from)
                ? OccurrenceStatus.paused
                : OccurrenceStatus.missed,
            changedAt:
                completedAt ?? DateTime(from.year, from.month, from.day + 1),
            note: _paused(pauses.values, id, from)
                ? (pauses.values
                              .where(
                                (p) =>
                                    p['itemId'] == id &&
                                    (p['from'] as String).compareTo(
                                          dayKey(from),
                                        ) <=
                                        0 &&
                                    (p['to'] as String).compareTo(
                                          dayKey(from),
                                        ) >=
                                        0,
                              )
                              .last['note']
                          as String? ??
                      '')
                : '',
            quantityUsed: completedAt != null && item.stockQuantity != null
                ? item.doseQuantity
                : 0,
          );
          pending[key] = record.toJson();
        }
      }
    }
    if (pending.isNotEmpty) {
      await store.writeJournal('records', pending, onlyIfAbsent: true);
      final updates = <String, Map<String, Object?>>{
        for (final entry in pending.entries)
          if (records[entry.key]?['status'] == 'pending')
            entry.key: entry.value,
      };
      if (updates.isNotEmpty) {
        await store.writeJournal('records', updates, onlyIfPending: true);
      }
    }
    await store.writeJournal('meta', {
      'reconciled': {
        'through': dayKey(today.subtract(const Duration(days: 1))),
      },
    });
  }

  Future<Map<String, List<DayTaskGroup>>> loadDays(
    DateTime from,
    DateTime to, {
    DateTime? now,
  }) async {
    await reconcile(now: now);
    final today = dateOnly(now ?? DateTime.now());
    final versions = await store.loadJournal('versions');
    final stored = await store.loadJournal('records', from: from, to: to);
    final pauses = await store.loadJournal('pauses');
    final completions = await store.loadCompletionTimes(from, to);
    final current = {
      for (final item in await store.loadItems(includeArchived: true))
        item.id!: item,
    };
    final ids = versions.values
        .map((entry) => (entry['item'] as Map)['id'] as int)
        .toSet();
    final recordsByDay = <String, Map<int, Map<String, OccurrenceRecord>>>{};
    for (final raw in stored.values) {
      final record = OccurrenceRecord.fromJson(raw);
      ((recordsByDay[dayKey(record.date)] ??= {})[record.item.id!] ??=
              {})[record.key] =
          record;
    }
    final result = <String, List<DayTaskGroup>>{};
    final persist = <String, Map<String, Object?>>{};
    for (
      var date = dateOnly(from);
      !date.isAfter(dateOnly(to));
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      final day = dayKey(date);
      final groups = <DayTaskGroup>[];
      for (final id in ids) {
        var item = _versionFor(versions.values, id, date);
        final dayRecords = Map<String, OccurrenceRecord>.from(
          recordsByDay[day]?[id] ?? const {},
        );
        final times = <int, ReminderTime>{};
        if (item != null && item.isScheduledOn(date)) {
          for (final time in item.times) {
            times[time.id!] = time;
          }
        }
        for (final record in dayRecords.values) {
          times[record.time.id!] = record.time;
          item ??= record.item;
        }
        if (times.isEmpty || item == null) continue;
        final paused = _paused(pauses.values, id, date);
        for (final time in times.values) {
          final key = completionKey(id, time.id!, date);
          if (!dayRecords.containsKey(key) && completions.containsKey(key)) {
            final record = OccurrenceRecord(
              item: item,
              time: time,
              date: date,
              status: OccurrenceStatus.completed,
              changedAt: completions[key]!,
              quantityUsed: item.stockQuantity == null ? 0 : item.doseQuantity,
            );
            dayRecords[key] = record;
            persist[key] = record.toJson();
          }
          if (!dayRecords.containsKey(key) &&
              paused &&
              !completions.containsKey(key)) {
            final record = OccurrenceRecord(
              item: item,
              time: time,
              date: date,
              status: OccurrenceStatus.paused,
              changedAt: now ?? DateTime.now(),
              note:
                  pauses.values
                          .where(
                            (p) =>
                                p['itemId'] == id &&
                                (p['from'] as String).compareTo(day) <= 0 &&
                                (p['to'] as String).compareTo(day) >= 0,
                          )
                          .last['note']
                      as String? ??
                  '',
            );
            dayRecords[key] = record;
            if (!date.isAfter(today)) persist[key] = record.toJson();
          }
        }
        final ordered = times.values.toList()
          ..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
        final live = date.isBefore(today) ? null : current[id];
        item = item.copyWith(
          times: ordered,
          usedQuantity: live?.usedQuantity ?? item.usedQuantity,
        );
        final completedTimes = <String, DateTime>{
          for (final time in ordered)
            completionKey(id, time.id!, date):
                ?completions[completionKey(id, time.id!, date)],
        };
        for (final record in dayRecords.values) {
          if (record.status == OccurrenceStatus.completed) {
            completedTimes[record.key] = record.changedAt;
          } else {
            completedTimes.remove(record.key);
          }
        }
        groups.add(
          DayTaskGroup(
            item: item,
            date: date,
            records: dayRecords,
            completedKeys: completedTimes.keys.toSet(),
            completionTimes: completedTimes,
          ),
        );
      }
      groups.sort((a, b) {
        if (a.allResolved != b.allResolved) return a.allResolved ? 1 : -1;
        if (a.allResolved &&
            a.lastCompletedAt != null &&
            b.lastCompletedAt != null) {
          return b.lastCompletedAt!.compareTo(a.lastCompletedAt!);
        }
        final order = a.nextMinute.compareTo(b.nextMinute);
        return order != 0 ? order : a.item.id!.compareTo(b.item.id!);
      });
      result[day] = groups;
    }
    if (persist.isNotEmpty) {
      await store.writeJournal('records', persist, onlyIfAbsent: true);
    }
    return result;
  }

  Future<List<DayTaskGroup>> loadDay(DateTime date) async =>
      (await loadDays(date, date))[dayKey(date)] ?? [];

  Future<OccurrenceRecord> occurrence(
    int itemId,
    int timeId,
    DateTime date,
  ) async {
    final key = completionKey(itemId, timeId, date);
    final existing = (await store.loadJournal('records', key: key))[key];
    if (existing != null) return OccurrenceRecord.fromJson(existing);
    await ensureVersions();
    final item = _versionFor(
      (await store.loadJournal('versions')).values,
      itemId,
      date,
    );
    if (item == null) throw StateError('没有对应日期的安排');
    final time = item.times.where((t) => t.id == timeId).first;
    return OccurrenceRecord(
      item: item,
      time: time,
      date: dateOnly(date),
      status: OccurrenceStatus.pending,
      changedAt: DateTime.now(),
    );
  }

  Future<void> recordCompletion(
    int itemId,
    int timeId,
    DateTime date,
    bool completed, {
    DateTime? completedAt,
  }) async {
    final record = await occurrence(itemId, timeId, date);
    final next = record.copyWith(
      status: completed
          ? OccurrenceStatus.completed
          : dateOnly(date).isBefore(dateOnly(DateTime.now()))
          ? OccurrenceStatus.missed
          : OccurrenceStatus.pending,
      changedAt: completedAt ?? DateTime.now(),
      quantityUsed: completed && record.item.stockQuantity != null
          ? record.item.doseQuantity
          : 0,
    );
    await store.writeJournal('records', {next.key: next.toJson()});
  }

  Future<void> setStatus(
    OccurrenceRecord record,
    OccurrenceStatus status, {
    String? note,
  }) async {
    if (dateOnly(record.date).isAfter(dateOnly(DateTime.now())) &&
        status == OccurrenceStatus.completed) {
      throw StateError('未来事项尚不能完成');
    }
    if (record.status != status &&
        (record.status == OccurrenceStatus.completed ||
            status == OccurrenceStatus.completed)) {
      await store.setCompletion(
        itemId: record.item.id!,
        reminderTimeId: record.time.id!,
        date: record.date,
        completed: status == OccurrenceStatus.completed,
      );
    }
    final latest = (await store.loadJournal(
      'records',
      key: record.key,
    ))[record.key];
    final base = latest == null ? record : OccurrenceRecord.fromJson(latest);
    final next = base.copyWith(
      status: status,
      note: note,
      changedAt:
          status == OccurrenceStatus.completed &&
              base.status == OccurrenceStatus.completed
          ? base.changedAt
          : DateTime.now(),
      quantityUsed: status == OccurrenceStatus.completed
          ? base.quantityUsed
          : 0,
    );
    await store.writeJournal('records', {next.key: next.toJson()});
  }

  Future<void> changeOnce(
    ReminderItem item,
    ReminderTime time,
    DateTime date,
    int minute,
  ) async {
    final record = await occurrence(item.id!, time.id!, date);
    if (record.status == OccurrenceStatus.completed) {
      throw StateError('已完成记录请在详情中查看');
    }
    final day = await loadDay(date);
    if (day
        .where((g) => g.item.id == item.id)
        .expand((g) => g.item.times)
        .any((t) => t.id != time.id && t.minuteOfDay == minute)) {
      throw StateError('这个提醒时间已经存在');
    }
    final next = record.copyWith(minute: minute, changedAt: DateTime.now());
    await store.writeJournal('records', {next.key: next.toJson()});
  }

  Future<void> pause(
    ReminderItem item,
    DateTime from,
    DateTime to,
    String note,
  ) async {
    if (dateOnly(from).isBefore(dateOnly(DateTime.now())) ||
        to.isBefore(from)) {
      throw ArgumentError('请选择今天起的暂停范围');
    }
    final key = '${item.id}:${DateTime.now().microsecondsSinceEpoch}';
    await store.writeJournal('pauses', {
      key: {
        'itemId': item.id,
        'from': dayKey(from),
        'to': dayKey(to),
        'note': note,
      },
    });
    // Preserve an explicit record for each elapsed occurrence, including today.
    await loadDay(from);
  }

  Future<void> resume(ReminderItem item) async {
    final today = dateOnly(DateTime.now());
    final day = dayKey(today);
    final pauses = await store.loadJournal('pauses');
    final changes = <String, Map<String, Object?>>{};
    for (final entry in pauses.entries) {
      if (entry.value['itemId'] == item.id &&
          (entry.value['to'] as String).compareTo(day) >= 0) {
        changes[entry.key] = {...entry.value, 'resumedOn': day};
      }
    }
    await store.writeJournal('pauses', changes);
    final records = await store.loadJournal('records');
    await store.writeJournal('records', {
      for (final entry in records.entries)
        if ((entry.value['item'] as Map)['id'] == item.id &&
            entry.value['date'] == day &&
            entry.value['status'] == 'paused')
          entry.key: OccurrenceRecord.fromJson(entry.value)
              .copyWith(
                status: OccurrenceStatus.pending,
                changedAt: DateTime.now(),
              )
              .toJson(),
    });
  }

  Future<List<OccurrenceRecord>> recordsFor(int itemId) async {
    await reconcile();
    await loadDay(DateTime.now());
    final records = (await store.loadJournal('records')).values
        .map(OccurrenceRecord.fromJson)
        .where((r) => r.item.id == itemId)
        .toList();
    records.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return records;
  }
}

String encodeBackup(
  List<ReminderItem> items,
  Map<String, Map<String, Map<String, Object?>>> journal,
  DailyThemeColor theme,
) => jsonEncode({
  'format': 'daily.backup',
  'version': 1,
  'exportedAt': DateTime.now().toIso8601String(),
  'theme': theme.name,
  'items': items.map(itemToJson).toList(),
  'journal': journal,
});

class DailyBackup {
  DailyBackup(this.items, this.journal, this.theme);
  final List<ReminderItem> items;
  final Map<String, Map<String, Map<String, Object?>>> journal;
  final DailyThemeColor theme;
  int get recordCount => journal['records']?.length ?? 0;
  factory DailyBackup.parse(String source) {
    try {
      if (source.length > 50 * 1024 * 1024) {
        throw const FormatException('备份文件过大');
      }
      final root = jsonDecode(source) as Map;
      if (root['format'] != 'daily.backup' || root['version'] != 1) {
        throw const FormatException('不支持的备份格式或版本');
      }
      void validateDate(Object? value) {
        if (value == null) return;
        if (value is! String ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
          throw const FormatException('日期格式无效');
        }
        final date = parseDay(value);
        if (dayKey(date) != value ||
            date.year < 1970 ||
            date.year > DateTime.now().year + 100) {
          throw const FormatException('日期范围无效');
        }
      }

      ReminderItem readItem(Object? raw) {
        final json = Map<String, Object?>.from(raw as Map);
        for (final key in ['start', 'end', 'production', 'expiry']) {
          validateDate(json[key]);
        }
        return itemFromJson(json);
      }

      final items = (root['items'] as List).map(readItem).toList();
      final ids = <int>{};
      final timeOwners = <int, int>{};
      void validateItem(ReminderItem item, {bool current = false}) {
        if (item.id == null ||
            item.id! <= 0 ||
            item.title.trim().isEmpty ||
            item.intervalDays < 1 ||
            item.times.isEmpty ||
            !item.doseQuantity.isFinite ||
            item.doseQuantity <= 0 ||
            item.stockQuantity != null &&
                (!item.stockQuantity!.isFinite || item.stockQuantity! < 0) ||
            item.weekdays.any((d) => d < 1 || d > 7) ||
            item.repeatKind == RepeatKind.weekly && item.weekdays.isEmpty ||
            item.endDate != null && item.endDate!.isBefore(item.startDate)) {
          throw const FormatException('事项数据无效');
        }
        if (current && !ids.add(item.id!)) {
          throw const FormatException('重复的事项编号');
        }
        final localIds = <int>{};
        for (final time in item.times) {
          if (time.id == null ||
              time.id! <= 0 ||
              !localIds.add(time.id!) ||
              time.minuteOfDay < 0 ||
              time.minuteOfDay >= 1440 ||
              timeOwners.containsKey(time.id) &&
                  timeOwners[time.id] != item.id) {
            throw const FormatException('提醒时间无效');
          }
          timeOwners[time.id!] = item.id!;
        }
      }

      for (final item in items) {
        validateItem(item, current: true);
      }
      final journal = <String, Map<String, Map<String, Object?>>>{};
      for (final kind in (root['journal'] as Map).entries) {
        if (!{'versions', 'records', 'pauses', 'meta'}.contains(kind.key)) {
          throw const FormatException('未知记录类型');
        }
        journal[kind.key as String] = {
          for (final e in (kind.value as Map).entries)
            e.key as String: Map<String, Object?>.from(e.value as Map),
        };
      }
      for (final entry in (journal['versions'] ?? {}).entries) {
        final item = readItem(entry.value['item']);
        validateItem(item);
        validateDate(entry.value['from']);
        if (!ids.contains(item.id)) throw const FormatException('安排缺少对应事项');
        final date = parseDay(entry.value['from'] as String);
        if (entry.key != '${item.id}:${dayKey(date)}') {
          throw const FormatException('安排编号不一致');
        }
      }
      for (final entry in (journal['records'] ?? {}).entries) {
        readItem(entry.value['item']);
        validateDate(entry.value['date']);
        final record = OccurrenceRecord.fromJson(entry.value);
        validateItem(record.item);
        if (!ids.contains(record.item.id) ||
            record.key != entry.key ||
            record.time.minuteOfDay < 0 ||
            record.time.minuteOfDay >= 1440 ||
            record.time.id == null ||
            record.time.id! <= 0 ||
            timeOwners[record.time.id] != record.item.id ||
            !record.quantityUsed.isFinite ||
            record.quantityUsed < 0) {
          throw const FormatException('历史记录无效');
        }
      }
      for (final pause in (journal['pauses'] ?? {}).values) {
        validateDate(pause['from']);
        validateDate(pause['to']);
        validateDate(pause['resumedOn']);
        if (parseDay(
          pause['to'] as String,
        ).isBefore(parseDay(pause['from'] as String))) {
          throw const FormatException('暂停范围无效');
        }
        if (!ids.contains(pause['itemId']) ||
            parseDay(pause['from'] as String).year < 1970) {
          throw const FormatException('暂停记录无效');
        }
        parseDay(pause['to'] as String);
        if (pause['note'] is! String) throw const FormatException('暂停备注无效');
      }
      for (final item in items) {
        if (!(journal['versions'] ?? {}).values.any(
          (e) => (e['item'] as Map)['id'] == item.id,
        )) {
          throw const FormatException('缺少安排版本');
        }
      }
      final through = journal['meta']?['reconciled']?['through'];
      if (through != null) {
        validateDate(through);
        if (parseDay(through as String).isAfter(dateOnly(DateTime.now()))) {
          throw const FormatException('历史检查日期无效');
        }
      }
      return DailyBackup(
        items,
        journal,
        DailyThemeColor.values.byName(root['theme'] as String),
      );
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('备份不完整或内容已损坏');
    }
  }
}
