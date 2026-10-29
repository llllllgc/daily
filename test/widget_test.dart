import 'package:daily/app.dart';
import 'package:daily/models.dart';
import 'package:daily/services/notification_service.dart';
import 'package:flutter/cupertino.dart';
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

ReminderItem eyeDropItem(DateTime today) {
  return ReminderItem(
    title: '滴眼液',
    iconKey: 'eye',
    startDate: today,
    repeatKind: RepeatKind.daily,
    times: const [ReminderTime(minuteOfDay: 10 * 60, sortOrder: 0)],
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

Future<void> scrollEditorUntilVisible(
  WidgetTester tester,
  Finder target,
) async {
  final editorScroll = find
      .descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    target,
    360,
    scrollable: editorScroll,
    maxScrolls: 20,
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

  testWidgets('a completed item sinks below pending items', (tester) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(
      seedItems: [singleItem(today), eyeDropItem(today)],
    );
    final saved = (await store.loadItems()).first;
    await pumpDaily(tester, store);

    expect(
      tester.getTopLeft(find.text('维生素 D')).dy,
      lessThan(tester.getTopLeft(find.text('滴眼液')).dy),
    );
    final startY = tester.getTopLeft(find.text('维生素 D')).dy;

    await tester.tap(find.byKey(ValueKey<String>('completion-${saved.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final movingY = tester.getTopLeft(find.text('维生素 D')).dy;
    expect(movingY, greaterThan(startY));

    await tester.pumpAndSettle();
    final endY = tester.getTopLeft(find.text('维生素 D')).dy;
    expect(movingY, lessThan(endY));

    expect(endY, greaterThan(tester.getTopLeft(find.text('滴眼液')).dy));

    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final returningY = tester.getTopLeft(find.text('维生素 D')).dy;
    expect(returningY, lessThan(endY));
    expect(returningY, greaterThan(startY));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('维生素 D')).dy, closeTo(startY, 1));
  });

  testWidgets('completed dose slides below pending doses', (tester) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(seedItems: [groupedItem(today)]);
    final saved = (await store.loadItems()).single;
    await pumpDaily(tester, store);
    await tester.tap(find.text('感冒药'));
    await tester.pumpAndSettle();

    final dose = find.byKey(ValueKey<String>('dose-${saved.times.first.id}'));
    final startY = tester.getTopLeft(dose).dy;
    await tester.tap(
      find.descendant(of: dose, matching: find.byType(CompletionButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final movingY = tester.getTopLeft(dose).dy;
    expect(movingY, greaterThan(startY));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(dose).dy, greaterThan(movingY));
  });

  testWidgets('completion confirmation disappears promptly', (tester) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(seedItems: [singleItem(today)]);
    final saved = (await store.loadItems()).single;
    await pumpDaily(tester, store);

    await tester.tap(find.byKey(ValueKey<String>('completion-${saved.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('已完成“维生素 D”'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('已完成“维生素 D”'), findsNothing);
  });

  testWidgets('changing tabs immediately clears completion confirmation', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(seedItems: [singleItem(today)]);
    final saved = (await store.loadItems()).single;
    await pumpDaily(tester, store);

    await tester.tap(find.byKey(ValueKey<String>('completion-${saved.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('已完成“维生素 D”'), findsOneWidget);

    await tester.tap(find.text('事项'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('已完成“维生素 D”'), findsNothing);
  });

  testWidgets('settings opens from the upper-right gear on both main pages', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final store = MemoryDailyStore();
    await pumpDaily(tester, store);

    expect(
      find.descendant(
        of: find.byType(AppBottomNavigation),
        matching: find.text('设置'),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('calendar-settings-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-settings-button')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(PageTopBar), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('事项'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('items-settings-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('items-settings-button')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('undoing a deletion preserves completion history', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(seedItems: [singleItem(today)]);
    final saved = (await store.loadItems()).single;
    await store.setCompletion(
      itemId: saved.id!,
      reminderTimeId: saved.times.single.id!,
      date: today,
      completed: true,
    );
    await pumpDaily(tester, store);

    await tester.tap(find.text('事项'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('撤销'), findsOneWidget);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    expect(await store.completionCount(), 1);
    expect((await store.loadItems()).single.id, saved.id);
  });

  testWidgets('new item shows icon and schedule controls directly', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final store = MemoryDailyStore();
    await pumpDaily(tester, store);

    await tester.tap(find.byKey(const Key('add-item-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('advanced-settings-toggle')), findsNothing);
    expect(find.text('图标'), findsOneWidget);

    final medicationChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey<String>('icon-medication')),
    );
    expect(medicationChip.selected, isTrue);
    await tester.tap(find.byKey(const ValueKey<String>('icon-vitamin')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey<String>('icon-vitamin')),
          )
          .selected,
      isTrue,
    );
    await scrollEditorUntilVisible(tester, find.text('重复'));
    expect(find.text('重复'), findsOneWidget);
    await scrollEditorUntilVisible(tester, find.text('提醒时间'));
    expect(find.text('提醒时间'), findsOneWidget);
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
    final saveButton = find.byKey(const Key('save-item-button'));
    await scrollEditorUntilVisible(tester, saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect((await store.loadItems()).single.title, '维生素 D');
    expect(find.text('维生素 D'), findsOneWidget);
  });

  testWidgets(
    'medicine form saves stock and interval, then completion uses stock',
    (tester) async {
      await setPhoneSize(tester);
      final store = MemoryDailyStore();
      await pumpDaily(tester, store);

      await tester.tap(find.byKey(const Key('add-item-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('item-title-field')), '药片');
      await tester.enterText(
        find.byKey(const Key('stock-quantity-field')),
        '5',
      );
      await tester.enterText(find.byKey(const Key('dose-quantity-field')), '2');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final intervalOption = find.text('隔几天');
      await scrollEditorUntilVisible(tester, intervalOption);
      await tester.tap(intervalOption);
      await tester.pumpAndSettle();
      final frequencyRow = find.byKey(const Key('frequency-picker-row'));
      await scrollEditorUntilVisible(tester, frequencyRow);
      await tester.tap(frequencyRow);
      await tester.pumpAndSettle();
      tester
          .widget<CupertinoPicker>(
            find.byKey(const Key('frequency-days-wheel')),
          )
          .onSelectedItemChanged!(2);
      await tester.pump();
      await tester.tap(find.byKey(const Key('frequency-picker-confirm')));
      await tester.pumpAndSettle();
      final saveButton = find.byKey(const Key('save-item-button'));
      await scrollEditorUntilVisible(tester, saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final item = (await store.loadItems()).single;
      expect(item.stockQuantity, 5);
      expect(item.doseQuantity, 2);
      expect(item.repeatKind, RepeatKind.interval);
      expect(item.intervalDays, 3);
      expect(find.text('剩余 5 片'), findsWidgets);

      await tester.tap(find.byKey(ValueKey<String>('completion-${item.id}')));
      await tester.pumpAndSettle();
      expect((await store.loadItems()).single.remainingQuantity, 3);
    },
  );

  testWidgets('frequency wheels set every two days and three times', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final store = MemoryDailyStore();
    await pumpDaily(tester, store);

    await tester.tap(find.byKey(const Key('add-item-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('item-title-field')), '测试药品');

    final frequencyRow = find.byKey(const Key('frequency-picker-row'));
    await scrollEditorUntilVisible(tester, frequencyRow);
    await tester.tap(frequencyRow);
    await tester.pumpAndSettle();

    var daysWheel = tester.widget<CupertinoPicker>(
      find.byKey(const Key('frequency-days-wheel')),
    );
    var timesWheel = tester.widget<CupertinoPicker>(
      find.byKey(const Key('frequency-times-wheel')),
    );
    daysWheel.onSelectedItemChanged!(1);
    timesWheel.onSelectedItemChanged!(2);
    await tester.pump();
    expect(find.text('每 2 天 · 3 次'), findsOneWidget);

    await tester.tap(find.byKey(const Key('frequency-picker-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('每天 · 1 次'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('editor-time-1')), findsNothing);

    await tester.tap(frequencyRow);
    await tester.pumpAndSettle();
    daysWheel = tester.widget<CupertinoPicker>(
      find.byKey(const Key('frequency-days-wheel')),
    );
    timesWheel = tester.widget<CupertinoPicker>(
      find.byKey(const Key('frequency-times-wheel')),
    );
    daysWheel.onSelectedItemChanged!(1);
    timesWheel.onSelectedItemChanged!(2);
    await tester.pump();
    await tester.tap(find.byKey(const Key('frequency-picker-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('每 2 天 · 3 次'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('editor-time-2')), findsOneWidget);

    final saveButton = find.byKey(const Key('save-item-button'));
    await scrollEditorUntilVisible(tester, saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final item = (await store.loadItems()).single;
    expect(item.repeatKind, RepeatKind.interval);
    expect(item.intervalDays, 2);
    expect(item.times, hasLength(3));
    expect(item.times.map((time) => time.minuteOfDay).toSet(), hasLength(3));
  });

  testWidgets('frequency picker settles immediately with reduced motion', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await setPhoneSize(tester);
    await pumpDaily(tester, MemoryDailyStore());

    await tester.tap(find.byKey(const Key('add-item-button')));
    await tester.pumpAndSettle();
    final frequencyRow = find.byKey(const Key('frequency-picker-row'));
    await scrollEditorUntilVisible(tester, frequencyRow);
    await tester.tap(frequencyRow);
    await tester.pump();

    expect(find.byKey(const Key('frequency-days-wheel')), findsOneWidget);
    tester
        .widget<CupertinoPicker>(find.byKey(const Key('frequency-times-wheel')))
        .onSelectedItemChanged!(1);
    await tester.pump();
    await tester.tap(find.byKey(const Key('frequency-picker-confirm')));
    await tester.pump();

    expect(find.byKey(const Key('frequency-times-wheel')), findsNothing);
    expect(find.text('每天 · 2 次'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('editor-time-1')), findsOneWidget);
  });

  testWidgets('new item reminder time can be changed', (tester) async {
    await setPhoneSize(tester);
    final store = MemoryDailyStore();
    await pumpDaily(tester, store);

    await tester.tap(find.byKey(const Key('add-item-button')));
    await tester.pumpAndSettle();
    final timeRow = find.byKey(const ValueKey<String>('editor-time-0'));
    await scrollEditorUntilVisible(tester, timeRow);
    await tester.tap(timeRow);
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
