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
      version: 2,
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
            interval_days INTEGER NOT NULL DEFAULT 2,
            weekdays TEXT NOT NULL DEFAULT '',
            stock_quantity REAL,
            dose_quantity REAL NOT NULL DEFAULT 1,
            stock_unit TEXT NOT NULL DEFAULT '片',
            production_date TEXT,
            expiry_date TEXT,
            used_quantity_base REAL NOT NULL DEFAULT 0,
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
            quantity_used REAL NOT NULL DEFAULT 0,
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE items ADD COLUMN interval_days INTEGER NOT NULL DEFAULT 2',
          );
          await db.execute('ALTER TABLE items ADD COLUMN stock_quantity REAL');
          await db.execute(
            'ALTER TABLE items ADD COLUMN dose_quantity REAL NOT NULL DEFAULT 1',
          );
          await db.execute(
            "ALTER TABLE items ADD COLUMN stock_unit TEXT NOT NULL DEFAULT '片'",
          );
          await db.execute('ALTER TABLE items ADD COLUMN production_date TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN expiry_date TEXT');
          await db.execute(
            'ALTER TABLE items ADD COLUMN used_quantity_base REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE completions ADD COLUMN quantity_used REAL NOT NULL DEFAULT 0',
          );
        }
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
    final usageRows = await db.rawQuery(
      'SELECT item_id, SUM(quantity_used) AS used FROM completions WHERE item_id IN ($placeholders) GROUP BY item_id',
      ids,
    );
    final usedByItem = <int, double>{
      for (final row in usageRows)
        row['item_id'] as int: (row['used'] as num).toDouble(),
    };
    return rows
        .map(
          (row) => _itemFromRow(
            row,
            timesByItem[row['id']] ?? const [],
            (row['used_quantity_base'] as num).toDouble() +
                (usedByItem[row['id']] ?? 0),
          ),
        )
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
    final usageRows = await txn.rawQuery(
      'SELECT SUM(quantity_used) AS used FROM completions WHERE item_id = ?',
      [id],
    );
    return _itemFromRow(
      itemRows.single,
      timeRows.map(_timeFromRow).toList(growable: false),
      (itemRows.single['used_quantity_base'] as num).toDouble() +
          ((usageRows.single['used'] as num?)?.toDouble() ?? 0),
    );
  }

  @override
  Future<ReminderItem> saveItem(ReminderItem item) async {
    final db = await database;
    return db.transaction((txn) async {
      final values = _itemValues(item);

      late final int itemId;
      if (item.id == null) {
        itemId = await txn.insert('items', values);
      } else {
        itemId = item.id!;
        final retainedTimeIds = item.times
            .map((time) => time.id)
            .whereType<int>()
            .toList();
        final placeholders = List.filled(retainedTimeIds.length, '?').join(',');
        final removedUsage = await txn.rawQuery(
          'SELECT SUM(quantity_used) AS used FROM completions WHERE item_id = ? ${retainedTimeIds.isEmpty ? '' : 'AND reminder_time_id NOT IN ($placeholders)'}',
          [itemId, ...retainedTimeIds],
        );
        values['used_quantity_base'] =
            item.usedQuantityBase +
            ((removedUsage.single['used'] as num?)?.toDouble() ?? 0);
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
  Future<DeletedReminder?> deleteItem(int itemId) async {
    final db = await database;
    return db.transaction((txn) async {
      final itemRows = await txn.query(
        'items',
        where: 'id = ?',
        whereArgs: [itemId],
      );
      if (itemRows.isEmpty) return null;
      final item = await _loadItem(itemId, txn);
      final completionRows = await txn.query(
        'completions',
        where: 'item_id = ?',
        whereArgs: [itemId],
        orderBy: 'id ASC',
      );
      final deleted = DeletedReminder(
        item: item,
        completions: completionRows
            .map(
              (row) => DeletedCompletion(
                reminderTimeId: row['reminder_time_id'] as int,
                date: parseDay(row['occurrence_date'] as String),
                completedAt: DateTime.parse(row['completed_at'] as String),
                quantityUsed: (row['quantity_used'] as num).toDouble(),
              ),
            )
            .toList(growable: false),
      );
      await txn.delete('items', where: 'id = ?', whereArgs: [itemId]);
      return deleted;
    });
  }

  @override
  Future<void> restoreDeletedItem(DeletedReminder deleted) async {
    final item = deleted.item;
    final itemId = item.id;
    if (itemId == null) {
      throw ArgumentError('A deleted reminder must retain its item id.');
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('items', <String, Object?>{
        'id': itemId,
        ..._itemValues(item),
      });
      for (final time in item.times) {
        final timeId = time.id;
        if (timeId == null) {
          throw ArgumentError('A deleted reminder time must retain its id.');
        }
        await txn.insert('reminder_times', <String, Object?>{
          'id': timeId,
          'item_id': itemId,
          'minute_of_day': time.minuteOfDay,
          'sort_order': time.sortOrder,
        });
      }
      for (final completion in deleted.completions) {
        await txn.insert('completions', <String, Object?>{
          'item_id': itemId,
          'reminder_time_id': completion.reminderTimeId,
          'occurrence_date': dayKey(completion.date),
          'completed_at': completion.completedAt.toIso8601String(),
          'quantity_used': completion.quantityUsed,
        });
      }
    });
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
    await db.transaction((txn) async {
      final itemRows = await txn.query(
        'items',
        columns: ['stock_quantity', 'dose_quantity'],
        where: 'id = ?',
        whereArgs: [itemId],
      );
      if (itemRows.isEmpty) throw StateError('Reminder no longer exists.');
      final item = itemRows.single;
      await txn.insert('completions', <String, Object?>{
        'item_id': itemId,
        'reminder_time_id': reminderTimeId,
        'occurrence_date': dayKey(date),
        'completed_at': DateTime.now().toIso8601String(),
        'quantity_used': item['stock_quantity'] == null
            ? 0
            : (item['dose_quantity'] as num).toDouble(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
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

  Map<String, Object?> _itemValues(ReminderItem item) {
    return <String, Object?>{
      'title': item.title.trim(),
      'icon_key': item.iconKey,
      'start_date': dayKey(item.startDate),
      'end_date': item.endDate == null ? null : dayKey(item.endDate!),
      'repeat_kind': item.repeatKind.name,
      'interval_days': item.intervalDays,
      'weekdays': (item.weekdays.toList()..sort()).join(','),
      'stock_quantity': item.stockQuantity,
      'dose_quantity': item.doseQuantity,
      'stock_unit': item.stockUnit,
      'production_date': item.productionDate == null
          ? null
          : dayKey(item.productionDate!),
      'expiry_date': item.expiryDate == null ? null : dayKey(item.expiryDate!),
      'used_quantity_base': item.usedQuantityBase,
      'snooze_minutes': item.snoozeMinutes,
      'alert_month_before': item.alertMonthBefore ? 1 : 0,
      'alert_week_before': item.alertWeekBefore ? 1 : 0,
      'archived': item.archived ? 1 : 0,
      'created_at': (item.createdAt ?? DateTime.now()).toIso8601String(),
    };
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
    double usedQuantity,
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
      intervalDays: row['interval_days'] as int,
      weekdays: weekdayText.isEmpty
          ? const <int>{}
          : weekdayText.split(',').map(int.parse).toSet(),
      times: times,
      stockQuantity: (row['stock_quantity'] as num?)?.toDouble(),
      doseQuantity: (row['dose_quantity'] as num).toDouble(),
      stockUnit: row['stock_unit'] as String,
      productionDate: row['production_date'] == null
          ? null
          : parseDay(row['production_date'] as String),
      expiryDate: row['expiry_date'] == null
          ? null
          : parseDay(row['expiry_date'] as String),
      usedQuantityBase: (row['used_quantity_base'] as num).toDouble(),
      usedQuantity: usedQuantity,
      snoozeMinutes: row['snooze_minutes'] as int?,
      alertMonthBefore: (row['alert_month_before'] as int) == 1,
      alertWeekBefore: (row['alert_week_before'] as int) == 1,
      archived: (row['archived'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
