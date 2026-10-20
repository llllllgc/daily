import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models.dart';

class SqliteDailyStore implements DailyStore {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    await initialize();
    return _database!;
  }

  @override
  Future<void> initialize() async {
    if (_database != null) return;
    final root = await getDatabasesPath();
    _database = await openDatabase(
      path.join(root, 'daily.sqlite3'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            icon_key TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT,
            repeat_kind TEXT NOT NULL,
            weekdays TEXT NOT NULL DEFAULT '',
            snooze_minutes INTEGER,
            alert_month_before INTEGER NOT NULL DEFAULT 1,
            alert_week_before INTEGER NOT NULL DEFAULT 1,
            archived INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE reminder_times (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id INTEGER NOT NULL,
            minute_of_day INTEGER NOT NULL,
            sort_order INTEGER NOT NULL,
            FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE completions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id INTEGER NOT NULL,
            reminder_time_id INTEGER NOT NULL,
            occurrence_date TEXT NOT NULL,
            completed_at TEXT NOT NULL,
            UNIQUE(item_id, reminder_time_id, occurrence_date),
            FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE,
            FOREIGN KEY(reminder_time_id) REFERENCES reminder_times(id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX completion_date_idx ON completions(occurrence_date)',
        );
        await db.execute(
          'CREATE INDEX reminder_item_idx ON reminder_times(item_id)',
        );
      },
    );
  }

  @override
  Future<List<ReminderItem>> loadItems({bool includeArchived = false}) async {
    final db = await database;
    final rows = await db.query(
      'items',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'created_at ASC, id ASC',
    );
    if (rows.isEmpty) return <ReminderItem>[];

    final ids = rows.map((row) => row['id'] as int).toList(growable: false);
    final placeholders = List.filled(ids.length, '?').join(',');
    final timeRows = await db.query(
      'reminder_times',
      where: 'item_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'sort_order ASC, minute_of_day ASC, id ASC',
    );
    final timesByItem = <int, List<ReminderTime>>{};
    for (final row in timeRows) {
      final time = _timeFromRow(row);
      timesByItem.putIfAbsent(time.itemId!, () => <ReminderTime>[]).add(time);
    }
    return rows
        .map((row) => _itemFromRow(row, timesByItem[row['id']] ?? const []))
        .toList(growable: false);
  }

  Future<ReminderItem> _loadItem(int id, Transaction txn) async {
    final itemRows = await txn.query('items', where: 'id = ?', whereArgs: [id]);
    final timeRows = await txn.query(
      'reminder_times',
      where: 'item_id = ?',
      whereArgs: [id],
      orderBy: 'sort_order ASC, minute_of_day ASC, id ASC',
    );
    return _itemFromRow(
      itemRows.single,
      timeRows.map(_timeFromRow).toList(growable: false),
    );
  }

  @override
  Future<ReminderItem> saveItem(ReminderItem item) async {
    final db = await database;
    return db.transaction((txn) async {
      final values = <String, Object?>{
        'title': item.title.trim(),
        'icon_key': item.iconKey,
        'start_date': dayKey(item.startDate),
        'end_date': item.endDate == null ? null : dayKey(item.endDate!),
        'repeat_kind': item.repeatKind.name,
        'weekdays': (item.weekdays.toList()..sort()).join(','),
        'snooze_minutes': item.snoozeMinutes,
        'alert_month_before': item.alertMonthBefore ? 1 : 0,
        'alert_week_before': item.alertWeekBefore ? 1 : 0,
        'archived': item.archived ? 1 : 0,
        'created_at': (item.createdAt ?? DateTime.now()).toIso8601String(),
      };

      late final int itemId;
      if (item.id == null) {
        itemId = await txn.insert('items', values);
      } else {
        itemId = item.id!;
        await txn.update('items', values, where: 'id = ?', whereArgs: [itemId]);
      }

      final retainedIds = <int>{};
      for (var index = 0; index < item.times.length; index++) {
        final time = item.times[index];
        final timeValues = <String, Object?>{
          'item_id': itemId,
          'minute_of_day': time.minuteOfDay,
          'sort_order': index,
        };
        if (time.id == null || item.id == null) {
          final timeId = await txn.insert('reminder_times', timeValues);
          retainedIds.add(timeId);
        } else {
          await txn.update(
            'reminder_times',
            timeValues,
            where: 'id = ? AND item_id = ?',
            whereArgs: [time.id, itemId],
          );
          retainedIds.add(time.id!);
        }
      }

      if (retainedIds.isEmpty) {
        await txn.delete(
          'reminder_times',
          where: 'item_id = ?',
          whereArgs: [itemId],
        );
      } else {
        final placeholders = List.filled(retainedIds.length, '?').join(',');
        await txn.delete(
          'reminder_times',
          where: 'item_id = ? AND id NOT IN ($placeholders)',
          whereArgs: [itemId, ...retainedIds],
        );
      }

      return _loadItem(itemId, txn);
    });
  }

  @override
  Future<void> deleteItem(int itemId) async {
    final db = await database;
    await db.delete('items', where: 'id = ?', whereArgs: [itemId]);
  }

  @override
  Future<void> setCompletion({
    required int itemId,
    required int reminderTimeId,
    required DateTime date,
    required bool completed,
  }) async {
    final db = await database;
    final where =
        'item_id = ? AND reminder_time_id = ? AND occurrence_date = ?';
    final args = <Object>[itemId, reminderTimeId, dayKey(date)];
    if (!completed) {
      await db.delete('completions', where: where, whereArgs: args);
      return;
    }
    await db.insert('completions', <String, Object?>{
      'item_id': itemId,
      'reminder_time_id': reminderTimeId,
      'occurrence_date': dayKey(date),
      'completed_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<Set<String>> loadCompletionKeys(DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.query(
      'completions',
      columns: ['item_id', 'reminder_time_id', 'occurrence_date'],
      where: 'occurrence_date >= ? AND occurrence_date <= ?',
      whereArgs: [dayKey(from), dayKey(to)],
    );
    return rows
        .map(
          (row) =>
              '${row['item_id']}:${row['reminder_time_id']}:${row['occurrence_date']}',
        )
        .toSet();
  }

  @override
  Future<int> completionCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM completions',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  ReminderTime _timeFromRow(Map<String, Object?> row) {
    return ReminderTime(
      id: row['id'] as int,
      itemId: row['item_id'] as int,
      minuteOfDay: row['minute_of_day'] as int,
      sortOrder: row['sort_order'] as int,
    );
  }

  ReminderItem _itemFromRow(
    Map<String, Object?> row,
    List<ReminderTime> times,
  ) {
    final weekdayText = row['weekdays'] as String? ?? '';
    return ReminderItem(
      id: row['id'] as int,
      title: row['title'] as String,
      iconKey: row['icon_key'] as String,
      startDate: parseDay(row['start_date'] as String),
      endDate: row['end_date'] == null
          ? null
          : parseDay(row['end_date'] as String),
      repeatKind: RepeatKind.values.byName(row['repeat_kind'] as String),
      weekdays: weekdayText.isEmpty
          ? const <int>{}
          : weekdayText.split(',').map(int.parse).toSet(),
      times: times,
      snoozeMinutes: row['snooze_minutes'] as int?,
      alertMonthBefore: (row['alert_month_before'] as int) == 1,
      alertWeekBefore: (row['alert_week_before'] as int) == 1,
      archived: (row['archived'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
