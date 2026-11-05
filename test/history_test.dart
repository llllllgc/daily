import 'dart:convert';
import 'dart:io';
import 'package:daily/models.dart';
import 'package:daily/data/daily_database.dart';
import 'package:daily/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final today = dateOnly(DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));
  ReminderItem plan({String title = '原安排'}) => ReminderItem(
    title: title,
    iconKey: 'medication',
    note: '原备注',
    startDate: today.subtract(const Duration(days: 3)),
    repeatKind: RepeatKind.daily,
    stockQuantity: 20,
    times: const [
      ReminderTime(minuteOfDay: 540, sortOrder: 0),
      ReminderTime(minuteOfDay: 1200, sortOrder: 1),
    ],
  );
  for (final sqlite in [false, true]) {
    group(sqlite ? 'SQLite' : 'Memory', () {
      late DailyStore store;
      Directory? temporary;
      setUp(() async {
        if (sqlite) {
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
          temporary = await Directory.systemTemp.createTemp('daily-history-');
          store = SqliteDailyStore(
            databasePath: '${temporary!.path}/daily.sqlite3',
          );
        } else {
          store = MemoryDailyStore();
        }
        await store.initialize();
      });
      tearDown(() async {
        if (store is SqliteDailyStore) {
          await (await (store as SqliteDailyStore).database).close();
        }
        await temporary?.delete(recursive: true);
      });
      test(
        'changing schedule and removing a time preserves past plans and quantities',
        () async {
          final item = await store.saveItem(plan());
          await store.setCompletion(
            itemId: item.id!,
            reminderTimeId: item.times.first.id!,
            date: yesterday,
            completed: true,
          );
          await store.saveItem(
            item.copyWith(
              title: '新安排',
              note: '新备注',
              repeatKind: RepeatKind.interval,
              intervalDays: 3,
              doseQuantity: 2,
              times: [item.times.last],
            ),
          );
          final past = (await store.history.loadDay(yesterday)).single;
          expect(past.item.title, '原安排');
          expect(past.item.note, '原备注');
          expect(past.item.times.length, 2);
          expect(past.completedCount, 1);
          expect(past.statusFor(past.item.times.last), OccurrenceStatus.missed);
          expect((await store.loadItems()).single.usedQuantity, 1);
          await store.setCompletion(
            itemId: item.id!,
            reminderTimeId: item.times.first.id!,
            date: yesterday,
            completed: false,
          );
          expect((await store.loadItems()).single.usedQuantity, 0);
        },
      );
      test(
        'one-time edits leave other dates unchanged and skip suppresses notifications',
        () async {
          final item = await store.saveItem(plan());
          await store.history.changeOnce(item, item.times.first, today, 600);
          expect(
            (await store.history.loadDay(
              today,
            )).single.item.times.first.minuteOfDay,
            600,
          );
          expect(
            (await store.history.loadDay(
              yesterday,
            )).single.item.times.first.minuteOfDay,
            540,
          );
          final record = await store.history.occurrence(
            item.id!,
            item.times.first.id!,
            today,
          );
          await store.history.setStatus(
            record,
            OccurrenceStatus.skipped,
            note: '外出',
          );
          final updated = (await store.history.loadDay(today)).single;
          expect(
            updated.statusFor(updated.item.times.first),
            OccurrenceStatus.skipped,
          );
          expect(updated.recordFor(updated.item.times.first)!.note, '外出');
          final scheduled = await notificationItems(
            store,
            await store.loadItems(),
            today,
          );
          expect(
            scheduled.where((i) => i.startDate == today).single.times.length,
            1,
          );
          expect(
            (await store.history.recordsFor(
              item.id!,
            )).where((r) => r.status == OccurrenceStatus.skipped).length,
            1,
          );
        },
      );
      test(
        'a pending occurrence becomes an individual missed record at rollover',
        () async {
          final item = await store.saveItem(plan());
          await store.history.changeOnce(item, item.times.first, today, 600);
          await store.history.reconcile(
            now: today.add(const Duration(days: 1)),
          );
          final records = await store.loadJournal('records');
          expect(
            records[completionKey(
              item.id!,
              item.times.first.id!,
              today,
            )]!['status'],
            'missed',
          );
          expect(
            records[completionKey(
              item.id!,
              item.times.last.id!,
              today,
            )]!['status'],
            'missed',
          );
        },
      );
      test('pause records each scheduled occurrence and can resume', () async {
        final item = await store.saveItem(plan());
        await store.history.pause(
          item,
          today,
          today.add(const Duration(days: 2)),
          '旅行',
        );
        expect((await store.history.loadDay(today)).single.excludedCount, 2);
        expect(
          (await store.history.loadDay(
            today.add(const Duration(days: 1)),
          )).single.excludedCount,
          2,
        );
        expect(
          (await store.history.recordsFor(
            item.id!,
          )).where((r) => r.status == OccurrenceStatus.paused).length,
          2,
        );
        final schedule = await notificationItems(
          store,
          await store.loadItems(),
          today,
        );
        expect(
          schedule.where(
            (i) => !i.startDate.isAfter(today.add(const Duration(days: 2))),
          ),
          isEmpty,
        );
        await store.history.resume(item);
        expect((await store.history.loadDay(today)).single.excludedCount, 0);
      });
      test(
        'archive hides future plans while preserving history, restore returns plans',
        () async {
          final item = await store.saveItem(plan());
          await store.saveItem(item.copyWith(archived: true));
          expect(await store.loadItems(), isEmpty);
          expect(await store.history.loadDay(today), isEmpty);
          expect(
            (await store.history.loadDay(yesterday)).single.item.title,
            '原安排',
          );
          await store.saveItem(item.copyWith(archived: false));
          expect((await store.history.loadDay(today)).single.item.title, '原安排');
        },
      );
      test(
        'backup roundtrip retains versions, removed times, notes and archived items',
        () async {
          final item = await store.saveItem(plan());
          await store.setCompletion(
            itemId: item.id!,
            reminderTimeId: item.times.first.id!,
            date: yesterday,
            completed: true,
          );
          final record = await store.history.occurrence(
            item.id!,
            item.times.last.id!,
            yesterday,
          );
          await store.history.setStatus(
            record,
            OccurrenceStatus.skipped,
            note: '原因',
          );
          await store.saveItem(
            item.copyWith(times: [item.times.last], archived: true),
          );
          await store.saveThemeColor(DailyThemeColor.blue);
          final backup = await store.exportBackup();
          final preview = DailyBackup.parse(backup);
          expect(preview.items.single.archived, true);
          await store.importBackup(backup);
          expect(await store.loadThemeColor(), DailyThemeColor.blue);
          final past = (await store.history.loadDay(yesterday)).single;
          expect(past.completedCount, 1);
          expect(past.item.times.length, 2);
          expect(past.records.values.any((r) => r.note == '原因'), true);
          expect(
            (await store.loadItems(includeArchived: true)).single.usedQuantity,
            1,
          );
          final added = await store.saveItem(plan(title: '新增'));
          expect(added.times.every((t) => t.id! > item.times.last.id!), true);
        },
      );
      test(
        'same-day removal still imports completed snapshots and reserves time IDs',
        () async {
          final item = await store.saveItem(plan().copyWith(startDate: today));
          await store.setCompletion(
            itemId: item.id!,
            reminderTimeId: item.times.last.id!,
            date: today,
            completed: true,
          );
          await store.saveItem(item.copyWith(times: [item.times.first]));
          await store.importBackup(await store.exportBackup());
          expect((await store.history.loadDay(today)).single.completedCount, 1);
          final added = await store.saveItem(plan(title: 'later'));
          expect(added.times.first.id!, greaterThan(item.times.last.id!));
        },
      );
      test(
        'editing a completion note preserves its actual completion time',
        () async {
          final item = await store.saveItem(plan());
          final timestamp = yesterday.add(const Duration(hours: 10));
          await store.setCompletion(
            itemId: item.id!,
            reminderTimeId: item.times.first.id!,
            date: yesterday,
            completed: true,
            completedAt: timestamp,
          );
          final record = await store.history.occurrence(
            item.id!,
            item.times.first.id!,
            yesterday,
          );
          await store.history.setStatus(
            record,
            OccurrenceStatus.completed,
            note: 'added note',
          );
          final updated = await store.history.occurrence(
            item.id!,
            item.times.first.id!,
            yesterday,
          );
          expect(updated.changedAt, timestamp);
          expect(updated.note, 'added note');
        },
      );
      test('invalid backup leaves current data untouched', () async {
        await store.saveItem(plan());
        final content =
            jsonDecode(await store.exportBackup()) as Map<String, dynamic>;
        (content['items'] as List).first['interval'] = 0;
        await expectLater(
          store.importBackup(jsonEncode(content)),
          throwsFormatException,
        );
        expect((await store.loadItems()).single.title, '原安排');
      });
    });
  }
}
