import 'package:daily/app.dart';
import 'package:daily/models.dart';
import 'package:daily/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ReminderItem groupedItem(DateTime today) {
  return ReminderItem(
    title: '感冒药',
    iconKey: 'medication',
    startDate: today,
    repeatKind: RepeatKind.daily,
    times: const [
      ReminderTime(minuteOfDay: 8 * 60, sortOrder: 0),
      ReminderTime(minuteOfDay: 13 * 60, sortOrder: 1),
      ReminderTime(minuteOfDay: 20 * 60, sortOrder: 2),
    ],
  );
}

ReminderItem singleItem(DateTime today) {
  return ReminderItem(
    title: '维生素 D',
    iconKey: 'vitamin',
    startDate: today,
    repeatKind: RepeatKind.daily,
    times: const [ReminderTime(minuteOfDay: 9 * 60, sortOrder: 0)],
  );
}

Future<void> setPhoneSize(WidgetTester tester, [double width = 390]) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> pumpDaily(WidgetTester tester, MemoryDailyStore store) async {
  await tester.pumpWidget(
    DailyApp(
      store: store,
      scheduler: const NoopReminderScheduler(),
      refreshSignal: AppRefreshSignal(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('multi-dose list expands in place on the calendar page', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(seedItems: [groupedItem(today)]);
    await pumpDaily(tester, store);

    expect(find.text('Daily.'), findsOneWidget);
    expect(find.text('感冒药'), findsOneWidget);
    expect(find.text('第 1 次'), findsNothing);

    await tester.ensureVisible(find.text('感冒药'));
    await tester.tap(find.text('感冒药'));
    await tester.pumpAndSettle();

    expect(find.text('第 1 次'), findsOneWidget);
    expect(find.text('第 2 次'), findsOneWidget);
    expect(find.text('第 3 次'), findsOneWidget);
    expect(find.byType(ItemEditorPage), findsNothing);
  });

  testWidgets('completed dose turns gray and sinks inside its own group', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(seedItems: [groupedItem(today)]);
    final saved = (await store.loadItems()).single;
    await store.setCompletion(
      itemId: saved.id!,
      reminderTimeId: saved.times[0].id!,
      date: today,
      completed: true,
    );
    await pumpDaily(tester, store);
    await tester.ensureVisible(find.text('感冒药'));
    await tester.tap(find.text('感冒药'));
    await tester.pumpAndSettle();

    final first = find.byKey(ValueKey<String>('dose-${saved.times[0].id}'));
    final second = find.byKey(ValueKey<String>('dose-${saved.times[1].id}'));
    expect(
      tester.getTopLeft(first).dy,
      greaterThan(tester.getTopLeft(second).dy),
    );

    final firstContainer = find.descendant(
      of: first,
      matching: find.byType(AnimatedContainer),
    );
    final decorated = tester.widget<AnimatedContainer>(firstContainer.first);
    final decoration = decorated.decoration! as BoxDecoration;
    expect(decoration.color, AppPalette.childNoteDone);
  });

  testWidgets('rapid completion taps only complete once and undo restores it', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(seedItems: [singleItem(today)]);
    final saved = (await store.loadItems()).single;
    await pumpDaily(tester, store);

    final button = find.byKey(ValueKey<String>('completion-${saved.id}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    var keys = await store.loadCompletionKeys(today, today);
    expect(
      keys,
      contains(completionKey(saved.id!, saved.times.single.id!, today)),
    );
    expect(find.text('撤销'), findsOneWidget);

    final undoAction = tester.widget<SnackBarAction>(
      find.byType(SnackBarAction),
    );
    undoAction.onPressed();
    await tester.pumpAndSettle();
    keys = await store.loadCompletionKeys(today, today);
    expect(
      keys,
      isNot(contains(completionKey(saved.id!, saved.times.single.id!, today))),
    );
  });

  testWidgets('new item keeps optional controls behind more settings', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final store = MemoryDailyStore();
    await pumpDaily(tester, store);

    await tester.tap(find.byKey(const Key('add-item-button')));
    await tester.pumpAndSettle();
    expect(find.text('图标'), findsNothing);
    expect(find.text('重复'), findsNothing);
    expect(find.text('提醒时间'), findsOneWidget);

    await tester.tap(find.byKey(const Key('advanced-settings-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('图标'), findsOneWidget);
    expect(find.text('重复'), findsOneWidget);
  });

  testWidgets('new item form persists a real item into the store', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final store = MemoryDailyStore();
    await pumpDaily(tester, store);

    await tester.tap(find.byKey(const Key('add-item-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('item-title-field')), '维生素 D');
    await tester.fling(
      find.byType(ListView).last,
      const Offset(0, -1800),
      1800,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-item-button')));
    await tester.pumpAndSettle();

    expect((await store.loadItems()).single.title, '维生素 D');
    expect(find.text('维生素 D'), findsOneWidget);
  });

  testWidgets('new item reminder time can be changed', (tester) async {
    await setPhoneSize(tester);
    final store = MemoryDailyStore();
    await pumpDaily(tester, store);

    await tester.tap(find.byKey(const Key('add-item-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('editor-time-0')));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();

    final timeFields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    expect(timeFields, findsNWidgets(2));
    await tester.enterText(timeFields.at(0), '10');
    await tester.enterText(timeFields.at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('10:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('input hints are lighter than entered text', (tester) async {
    await setPhoneSize(tester);
    final store = MemoryDailyStore();
    await pumpDaily(tester, store);

    await tester.tap(find.byKey(const Key('add-item-button')));
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('item-title-field'));
    final context = tester.element(field);
    final theme = Theme.of(context);
    final hintColor = theme.inputDecorationTheme.hintStyle?.color;
    final inputColor = theme.textTheme.bodyLarge?.color;

    expect(hintColor, isNotNull);
    expect(hintColor, isNot(inputColor));
    expect(
      hintColor!.computeLuminance(),
      greaterThan(inputColor!.computeLuminance()),
    );
  });

  testWidgets('calendar has no layout exception at supported widths', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in <double>[320, 375, 414, 768]) {
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(
        DailyApp(
          store: MemoryDailyStore(),
          scheduler: const NoopReminderScheduler(),
          refreshSignal: AppRefreshSignal(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width: $width');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('future calendar dates do not show status dots', (tester) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final store = MemoryDailyStore(seedItems: [groupedItem(today)]);

    await pumpDaily(tester, store);

    expect(
      find.byKey(ValueKey<String>('calendar-status-${dayKey(today)}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('calendar-status-${dayKey(tomorrow)}')),
      findsNothing,
    );
  });

  testWidgets('calendar does not show the four status legend labels', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await pumpDaily(tester, MemoryDailyStore());

    expect(find.text('待记录'), findsNothing);
    expect(find.text('进行中'), findsNothing);
    expect(find.text('已完成'), findsNothing);
    expect(find.text('有遗漏'), findsNothing);
  });
}
