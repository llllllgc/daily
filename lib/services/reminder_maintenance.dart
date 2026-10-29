import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../data/daily_database.dart';
import 'notification_service.dart';

const _maintenanceUniqueName = 'daily.reminder-maintenance';
const _maintenanceTaskName = 'daily.refresh-reminder-schedule';

@pragma('vm:entry-point')
void reminderMaintenanceDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _maintenanceTaskName) return true;
    try {
      final store = SqliteDailyStore();
      await store.initialize();
      final scheduler = NotificationService(store: store);
      await scheduler.initialize();
      await scheduler.sync(await store.loadItems());
      return true;
    } on Object {
      return false;
    }
  });
}

Future<void> initializeReminderMaintenance() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Workmanager().initialize(reminderMaintenanceDispatcher);
    await Workmanager().registerPeriodicTask(
      _maintenanceUniqueName,
      _maintenanceTaskName,
      frequency: const Duration(hours: 12),
      initialDelay: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  } on Object {
    // Foreground startup still performs a full sync. A future launch retries
    // background registration if an OEM temporarily rejects WorkManager.
  }
}
