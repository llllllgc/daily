import 'dart:convert';
import 'package:flutter/services.dart';
import '../models.dart';

class DeviceBridge {
  static const channel = MethodChannel('daily/data');
  static Future<bool> exportFile(String content) async =>
      await channel.invokeMethod<bool>('exportBackup', {
        'content': content,
        'name': 'Daily-${dayKey(DateTime.now())}.json',
      }) ??
      false;
  static Future<String?> importFile() =>
      channel.invokeMethod<String>('importBackup');
  static int _widgetRevision = 0;
  static Future<void> updateWidget(DailyStore store) async {
    final revision = ++_widgetRevision;
    final today = dateOnly(DateTime.now());
    final days = await store.history.loadDays(
      today,
      today.add(const Duration(days: 30)),
    );
    final payload = {
      'updated': DateTime.now().toIso8601String(),
      'days': [
        for (final entry in days.entries)
          {
            'date': entry.key,
            'total': entry.value.fold<int>(
              0,
              (s, g) => s + g.item.times.length,
            ),
            'completed': entry.value.fold<int>(
              0,
              (s, g) => s + g.completedCount,
            ),
            'remaining': entry.value.fold<int>(
              0,
              (s, g) =>
                  s + g.item.times.length - g.completedCount - g.excludedCount,
            ),
            'tasks': [
              for (final group in entry.value)
                for (final time in group.item.times)
                  if (!group.isCompleted(time) && !group.isExcluded(time))
                    {'title': group.item.title, 'time': time.label},
            ],
          },
      ],
    };
    if (revision != _widgetRevision) return;
    try {
      await channel.invokeMethod<void>('updateWidget', {
        'content': jsonEncode(payload),
      });
    } on MissingPluginException {
      /* Widget targets are available on iOS/Android. */
    }
  }
}
