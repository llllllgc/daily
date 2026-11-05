import 'dart:io';
import 'package:daily/data/daily_database.dart';
import 'package:daily/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'version 3 upgrade retains completion details and historical time IDs',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp('daily-v3-');
      final dbPath = '${directory.path}/daily.sqlite3';
      final today = dateOnly(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));
      final legacy = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE items (id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,icon_key TEXT NOT NULL,start_date TEXT NOT NULL,end_date TEXT,repeat_kind TEXT NOT NULL,interval_days INTEGER NOT NULL DEFAULT 2,weekdays TEXT NOT NULL DEFAULT "",stock_quantity REAL,dose_quantity REAL NOT NULL DEFAULT 1,stock_unit TEXT NOT NULL DEFAULT "片",production_date TEXT,expiry_date TEXT,used_quantity_base REAL NOT NULL DEFAULT 0,snooze_minutes INTEGER,alert_month_before INTEGER NOT NULL DEFAULT 1,alert_week_before INTEGER NOT NULL DEFAULT 1,archived INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE reminder_times (id INTEGER PRIMARY KEY AUTOINCREMENT,item_id INTEGER NOT NULL,minute_of_day INTEGER NOT NULL,sort_order INTEGER NOT NULL,FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE)',
            );
            await db.execute(
              'CREATE TABLE completions (id INTEGER PRIMARY KEY AUTOINCREMENT,item_id INTEGER NOT NULL,reminder_time_id INTEGER NOT NULL,occurrence_date TEXT NOT NULL,completed_at TEXT NOT NULL,quantity_used REAL NOT NULL DEFAULT 0,UNIQUE(item_id,reminder_time_id,occurrence_date),FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE,FOREIGN KEY(reminder_time_id) REFERENCES reminder_times(id) ON DELETE CASCADE)',
            );
            await db.insert('items', {
              'id': 7,
              'title': '原事项',
              'icon_key': 'medication',
              'start_date': dayKey(yesterday),
              'repeat_kind': 'daily',
              'stock_quantity': 10,
              'created_at': yesterday.toIso8601String(),
            });
            await db.insert('reminder_times', {
              'id': 11,
              'item_id': 7,
              'minute_of_day': 540,
              'sort_order': 0,
            });
            await db.insert('reminder_times', {
              'id': 12,
              'item_id': 7,
              'minute_of_day': 1200,
              'sort_order': 1,
            });
            await db.insert('completions', {
              'item_id': 7,
              'reminder_time_id': 12,
              'occurrence_date': dayKey(yesterday),
              'completed_at': yesterday
                  .add(const Duration(hours: 20))
                  .toIso8601String(),
              'quantity_used': 1,
            });
          },
        ),
      );
      await legacy.close();
      final store = SqliteDailyStore(databasePath: dbPath);
      await store.initialize();
      try {
        final item = (await store.loadItems()).single;
        expect(item.note, '');
        expect(item.remainingQuantity, 9);
        await store.saveItem(
          item.copyWith(title: '新事项', times: [item.times.first]),
        );
        final history = (await store.history.loadDay(yesterday)).single;
        expect(history.item.title, '原事项');
        expect(history.item.times.map((t) => t.id), [11, 12]);
        expect(history.completedCount, 1);
        await store.importBackup(await store.exportBackup());
        expect(
          (await store.history.loadDay(yesterday)).single.completedCount,
          1,
        );
        expect((await store.loadItems()).single.remainingQuantity, 9);
      } finally {
        await (await store.database).close();
        await directory.delete(recursive: true);
      }
    },
  );
}
