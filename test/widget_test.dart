import 'dart:async';

import 'package:daily/app.dart';
import 'package:daily/models.dart';
import 'package:daily/services/notification_service.dart';
import 'package:daily/widgets/completion_progress_ring.dart';
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

class PausableDailyStore extends MemoryDailyStore {
  PausableDailyStore({super.seedItems});

  Completer<void>? loadingGate;

  @override
  Future<List<ReminderItem>> loadItems({bool includeArchived = false}) async {
    final items = await super.loadItems(includeArchived: includeArchived);
    await loadingGate?.future;
    return items;
  }
}

class DeferredCompletionStore extends MemoryDailyStore {
  DeferredCompletionStore({super.seedItems});

  bool defer = false;
  final pending = <Completer<Map<String, DateTime>>>[];

  @override
  Future<Map<String, DateTime>> loadCompletionTimes(
    DateTime from,
    DateTime to,
  ) {
    if (!defer) return super.loadCompletionTimes(from, to);
    final result = Completer<Map<String, DateTime>>();
    pending.add(result);
    return result.future;
  }
}

class RecordingReminderScheduler extends NoopReminderScheduler {
  List<ReminderItem> lastSynced = [];

  @override
  Future<void> sync(List<ReminderItem> items) async {
    lastSynced = List.of(items);
  }
}

Future<void> enterTime(WidgetTester tester, String hour, String minute) async {
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), hour);
  await tester.enterText(fields.at(1), minute);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'navigation and editor icon tiles keep labels in semantics only',
    (tester) async {
      await setPhoneSize(tester);
      await pumpDaily(tester, MemoryDailyStore());
      expect(
        find.descendant(
          of: find.byType(AppBottomNavigation),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(find.byTooltip('日历'), findsOneWidget);
      expect(find.byTooltip('事项'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tab-items')));
      await tester.pumpAndSettle();
      expect(find.byType(ItemsPage), findsOneWidget);
      await tester.tap(find.byKey(const Key('tab-calendar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-item-button')));
      await tester.pumpAndSettle();
      final category = find.byKey(const ValueKey('icon-vitamin'));
      expect(
        find.descendant(of: category, matching: find.byType(Text)),
        findsNothing,
      );
      expect(find.byTooltip('营养'), findsOneWidget);
      await tester.tap(category);
      await tester.tap(find.byKey(const Key('editor-icon-settings')));
      await tester.pumpAndSettle();
      final icon = find.byKey(const ValueKey('item-icon-vitamin'));
      // Both the category tiles and the individual icon tiles are icon-only.
      expect(icon, findsOneWidget);
      expect(
        find.descendant(of: icon, matching: find.byType(Text)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('daily and item rings track every dose completion and undo', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(
      seedItems: [
        groupedItem(today).copyWith(
          times: [
            for (var index = 0; index < 4; index++)
              ReminderTime(minuteOfDay: (8 + index * 3) * 60, sortOrder: index),
          ],
        ),
      ],
    );
    final item = (await store.loadItems()).single;
    await pumpDaily(tester, store);
    await tester.tap(find.text('感冒药'));
    await tester.pumpAndSettle();
    final indicators = find.descendant(
      of: find.byType(CompletionProgressRing),
      matching: find.byType(CircularProgressIndicator),
    );
    for (var count = 0; count <= 4; count++) {
      expect(indicators, findsNWidgets(2));
      for (final indicator in tester.widgetList<CircularProgressIndicator>(
        indicators,
      )) {
        expect(indicator.value, count / 4);
        expect(
          indicator.color,
          count < 2
              ? CompletionProgressRing.lowColor
              : count < 4
              ? CompletionProgressRing.partialColor
              : CompletionProgressRing.completeColor,
        );
      }
      if (count == 4) break;
      final row = find.byKey(ValueKey('dose-${item.times[count].id}'));
      await tester.tap(
        find.descendant(of: row, matching: find.byType(CompletionButton)),
      );
      await tester.pumpAndSettle();
    }
    // The completion control intentionally rejects repeated taps for 550 ms.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 560)),
    );
    final row = find.byKey(ValueKey('dose-${item.times.last.id}'));
    await tester.tap(
      find.descendant(of: row, matching: find.byType(CompletionButton)),
    );
    await tester.pumpAndSettle();
    for (final indicator in tester.widgetList<CircularProgressIndicator>(
      indicators,
    )) {
      expect(indicator.value, .75);
      expect(indicator.color, CompletionProgressRing.partialColor);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'week view fits four tasks and month expansion preserves their order',
    (tester) async {
      await setPhoneSize(tester);
      final today = dateOnly(DateTime.now());
      final store = MemoryDailyStore(
        seedItems: [
          singleItem(today),
          eyeDropItem(today),
          singleItem(today).copyWith(title: '喝水'),
          singleItem(today).copyWith(title: '运动'),
        ],
      );
      final items = await store.loadItems();
      await store.setCompletion(
        itemId: items.first.id!,
        reminderTimeId: items.first.times.single.id!,
        date: today,
        completed: true,
      );
      await pumpDaily(tester, store);
      expect(find.byType(CalendarDayCell), findsNWidgets(7));
      final bottom = tester.getTopLeft(find.byType(AppBottomNavigation)).dy;
      for (final card in find.byType(TaskGroupView).evaluate()) {
        expect(
          tester.getBottomLeft(find.byWidget(card.widget)).dy,
          lessThan(bottom),
        );
      }
      final pending = find.byKey(Key('group-${items[1].id}'));
      final completed = find.byKey(Key('group-${items.first.id}'));
      final collapsedY = tester.getTopLeft(pending).dy;
      final toggle = find.byKey(const Key('calendar-view-toggle'));
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final movingY = tester.getTopLeft(pending).dy;
      expect(movingY, greaterThan(collapsedY));
      expect(movingY, lessThan(collapsedY + 260));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDayCell), findsNWidgets(42));
      expect(tester.getTopLeft(pending).dy, closeTo(collapsedY + 260, 0.1));
      expect(
        tester.getTopLeft(completed).dy,
        greaterThan(tester.getTopLeft(pending).dy),
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDayCell), findsNWidgets(7));
      expect(tester.getTopLeft(pending).dy, closeTo(collapsedY, 0.1));
      final button = find.byKey(Key('completion-${items.first.id}'));
      expect(tester.widget<CompletionButton>(button).completed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'swiping weeks crosses months and today returns to the current date',
    (tester) async {
      await setPhoneSize(tester);
      final today = dateOnly(DateTime.now());
      await pumpDaily(tester, MemoryDailyStore());
      final calendar = find.byType(CalendarDates);
      final swipe = find.byKey(const Key('calendar-swipe-area'));
      for (var week = 1; week <= 5; week++) {
        await tester.drag(swipe, const Offset(-180, 0));
        await tester.pumpAndSettle();
        final selected = DateTime(
          today.year,
          today.month,
          today.day + week * 7,
        );
        final dates = tester.widget<CalendarDates>(calendar);
        expect(dates.selectedDate, selected);
        expect(dates.visibleMonth, DateTime(selected.year, selected.month));
        expect(find.byType(CalendarDayCell), findsNWidgets(7));
      }
      await tester.drag(swipe, const Offset(180, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CalendarDates>(calendar).selectedDate,
        DateTime(today.year, today.month, today.day + 28),
      );
      await tester.tap(find.byKey(const Key('calendar-today-button')));
      await tester.pumpAndSettle();
      expect(tester.widget<CalendarDates>(calendar).selectedDate, today);
      expect(find.byKey(const Key('calendar-today-button')), findsNothing);
      final quickSwipe = await tester.startGesture(tester.getCenter(swipe));
      await quickSwipe.moveBy(const Offset(-160, 0));
      await quickSwipe.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<CalendarDates>(calendar).selectedDate,
        DateTime(today.year, today.month, today.day + 7),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('today stays outlined when another date is selected', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    await pumpDaily(tester, MemoryDailyStore());
    final other = find
        .byWidgetPredicate(
          (widget) =>
              widget is CalendarDayCell &&
              !DateUtils.isSameDay(widget.date, today),
        )
        .first;
    await tester.tap(other);
    await tester.pumpAndSettle();
    final todayCell = find.byWidgetPredicate(
      (widget) =>
          widget is CalendarDayCell && DateUtils.isSameDay(widget.date, today),
    );
    expect(tester.widget<CalendarDayCell>(todayCell).selected, isFalse);
    final circle = tester.widget<AnimatedContainer>(
      find.descendant(of: todayCell, matching: find.byType(AnimatedContainer)),
    );
    expect((circle.decoration! as BoxDecoration).border, isNotNull);
    expect(find.byKey(const Key('calendar-today-button')), findsOneWidget);
  });

  testWidgets('reduced motion switches calendar height immediately', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await setPhoneSize(tester);
    await pumpDaily(tester, MemoryDailyStore());
    final summary = find.byType(DailySummary);
    final collapsedY = tester.getTopLeft(summary).dy;
    final toggle = find.byKey(const Key('calendar-view-toggle'));
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.getTopLeft(summary).dy, closeTo(collapsedY + 260, 0.1));
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.getTopLeft(summary).dy, closeTo(collapsedY, 0.1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(summary).dy, closeTo(collapsedY, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'month selection and collapsing keep expanded doses and completion',
    (tester) async {
      await setPhoneSize(tester);
      final today = dateOnly(DateTime.now());
      final store = MemoryDailyStore(seedItems: [groupedItem(today)]);
      final saved = (await store.loadItems()).single;
      await pumpDaily(tester, store);
      await tester.tap(find.text(saved.title));
      await tester.pumpAndSettle();
      final dose = find.byKey(Key('dose-${saved.times.first.id}'));
      await tester.tap(
        find.descendant(of: dose, matching: find.byType(CompletionButton)),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('calendar-view-toggle'));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<DoseRow>(dose).completed, isTrue);
      expect(find.byType(DoseRow), findsNWidgets(3));

      final adjacent = find.byType(CalendarDayCell).last;
      final selected = tester.widget<CalendarDayCell>(adjacent).date;
      await tester.tap(adjacent);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CalendarDates>(find.byType(CalendarDates)).visibleMonth,
        DateTime(selected.year, selected.month),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CalendarDates>(find.byType(CalendarDates)).selectedDate,
        selected,
      );
      expect(find.byType(CalendarDayCell), findsNWidgets(7));

      await tester.tap(find.byKey(const Key('calendar-today-button')));
      await tester.pumpAndSettle();
      expect(find.byType(DoseRow), findsNWidgets(3));
      expect(tester.widget<DoseRow>(dose).completed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid month changes ignore an older response arriving last', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final store = DeferredCompletionStore(seedItems: [singleItem(today)]);
    final saved = (await store.loadItems()).single;
    await pumpDaily(tester, store);
    await tester.tap(find.byKey(const Key('calendar-view-toggle')));
    await tester.pumpAndSettle();
    store.defer = true;
    await tester.tap(find.byTooltip('下个月'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('上个月'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(store.pending, hasLength(2));

    store.pending.last.complete({
      completionKey(saved.id!, saved.times.single.id!, today): DateTime.now(),
    });
    await tester.pumpAndSettle();
    final status = find.byKey(Key('calendar-status-${dayKey(today)}'));
    Color? statusColor() =>
        (tester.widget<Container>(status).decoration! as BoxDecoration).color;
    expect(statusColor(), AppPalette.pine);
    store.pending.first.complete({});
    await tester.pumpAndSettle();
    expect(statusColor(), AppPalette.pine);
    expect(tester.takeException(), isNull);
  });

  testWidgets('undo after selecting another date restores the original date', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final store = MemoryDailyStore(seedItems: [singleItem(today)]);
    final saved = (await store.loadItems()).single;
    await pumpDaily(tester, store);
    await tester.tap(find.byKey(const Key('calendar-view-toggle')));
    await tester.pumpAndSettle();
    final button = find.byKey(Key('completion-${saved.id}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final tomorrowCell = find.byWidgetPredicate(
      (widget) =>
          widget is CalendarDayCell && dayKey(widget.date) == dayKey(tomorrow),
    );
    await tester.ensureVisible(tomorrowCell);
    await tester.tap(tomorrowCell);
    await tester.pumpAndSettle();
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pumpAndSettle();
    expect(await store.loadCompletionKeys(today, tomorrow), isEmpty);
    expect(tester.widget<CompletionButton>(button).completed, isFalse);
  });

  testWidgets('animated dose rows fit large text on a narrow phone', (
    tester,
  ) async {
    await setPhoneSize(tester, 320);
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(seedItems: [groupedItem(today)]);
    final saved = (await store.loadItems()).single;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DoseRail(
                  group: DayTaskGroup(
                    item: saved,
                    date: today,
                    completedKeys: const {},
                  ),
                  onToggleCompletion: (_) {},
                  onEditTime: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('第 3 次'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion is visible before moving and undo animates it back', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final today = dateOnly(DateTime.now());
    final store = MemoryDailyStore(seedItems: [groupedItem(today)]);
    final saved = (await store.loadItems()).single;
    await pumpDaily(tester, store);
    await tester.tap(find.text('感冒药'));
    await tester.pumpAndSettle();

    final first = find.byKey(ValueKey<String>('dose-${saved.times[0].id}'));
    final third = find.byKey(ValueKey<String>('dose-${saved.times[2].id}'));
    final button = find.descendant(
      of: first,
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final start = tester.getTopLeft(first).dy;
    final destination = tester.getTopLeft(third).dy;

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget<DoseRow>(first).completed, isTrue);
    final fill = find.descendant(
      of: first,
      matching: find.byKey(const Key('completion-fill')),
    );
    final fillProgress = tester.widget<FractionallySizedBox>(fill).widthFactor!;
    expect(fillProgress, greaterThan(0));
    expect(fillProgress, lessThan(1));
    expect(tester.getTopLeft(first).dy, closeTo(start, 0.1));
    expect(find.byType(TaskListSkeleton), findsNothing);

    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(first).dy, greaterThan(start));
    expect(tester.getTopLeft(first).dy, lessThan(destination));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(first).dy, closeTo(destination, 0.1));

    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final reverseProgress = tester
        .widget<FractionallySizedBox>(fill)
        .widthFactor!;
    expect(reverseProgress, greaterThan(0));
    expect(reverseProgress, lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(first).dy, closeTo(start, 0.1));
    expect(tester.widget<DoseRow>(first).completed, isFalse);
    expect(await store.loadCompletionKeys(today, today), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh keeps loaded rows and their expansion visible', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final store = PausableDailyStore(
      seedItems: [groupedItem(dateOnly(DateTime.now()))],
    );
    final refreshSignal = AppRefreshSignal();
    addTearDown(refreshSignal.dispose);
    await tester.pumpWidget(
      DailyApp(
        store: store,
        scheduler: const NoopReminderScheduler(),
        refreshSignal: refreshSignal,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('感冒药'));
    await tester.pumpAndSettle();

    store.loadingGate = Completer<void>();
    refreshSignal.notify();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('感冒药'), findsOneWidget);
    expect(find.byType(DoseRow), findsNWidgets(3));
    expect(find.byType(TaskListSkeleton), findsNothing);

    store.loadingGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(DoseRow), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab switching preserves scroll expansion and item filter', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final store = MemoryDailyStore(
      seedItems: [
        groupedItem(dateOnly(DateTime.now())),
        for (var index = 0; index < 5; index++)
          singleItem(dateOnly(DateTime.now())).copyWith(title: '事项 $index'),
      ],
    );
    await pumpDaily(tester, store);
    await tester.tap(find.text('感冒药'));
    await tester.pumpAndSettle();
    final calendar = find.byKey(const PageStorageKey<String>('calendar-page'));
    await tester.drag(calendar, const Offset(0, -140));
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(of: calendar, matching: find.byType(Scrollable))
        .first;
    final offset = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(offset, greaterThan(0));

    await tester.tap(find.byKey(const Key('tab-items')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('item-filter-all')));
    await tester.pumpAndSettle();
    final indicator = find.byKey(const Key('item-filter-indicator'));
    final selectedX = tester.getTopLeft(indicator).dx;
    await tester.tap(find.byKey(const Key('tab-calendar')));
    await tester.pumpAndSettle();
    expect(find.byType(DoseRow), findsNWidgets(3));
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(offset, 0.1),
    );
    await tester.tap(find.byKey(const Key('tab-items')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(indicator).dx, closeTo(selectedX, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS editor supports the native edge swipe back gesture', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await pumpDaily(tester, MemoryDailyStore());
    await tester.tap(find.byKey(const Key('add-item-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditorPage), findsOneWidget);

    await tester.dragFrom(const Offset(5, 400), const Offset(320, 0));
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditorPage), findsNothing);
    expect(find.text('Daily.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('reduced motion reorders immediately without a delayed jump', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await setPhoneSize(tester);
    final store = MemoryDailyStore(
      seedItems: [groupedItem(dateOnly(DateTime.now()))],
    );
    final saved = (await store.loadItems()).single;
    await pumpDaily(tester, store);
    await tester.tap(find.text('感冒药'));
    await tester.pump();
    final first = find.byKey(ValueKey<String>('dose-${saved.times[0].id}'));
    final second = find.byKey(ValueKey<String>('dose-${saved.times[1].id}'));
    final button = find.descendant(
      of: first,
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    await tester.pump();
    expect(
      tester.getTopLeft(first).dy,
      greaterThan(tester.getTopLeft(second).dy),
    );
    final settledY = tester.getTopLeft(first).dy;
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(first).dy, settledY);
    expect(tester.takeException(), isNull);
  });

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

    final fill = find.descendant(
      of: first,
      matching: find.byKey(const Key('completion-fill')),
    );
    expect(tester.widget<FractionallySizedBox>(fill).widthFactor, 1);
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
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump(const Duration(milliseconds: 80));
    final movingY = tester.getTopLeft(find.text('维生素 D')).dy;
    expect(movingY, greaterThan(startY));

    await tester.pumpAndSettle();
    final endY = tester.getTopLeft(find.text('维生素 D')).dy;
    expect(movingY, lessThan(endY));

    expect(endY, greaterThan(tester.getTopLeft(find.text('滴眼液')).dy));

    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump(const Duration(milliseconds: 80));
    final returningY = tester.getTopLeft(find.text('维生素 D')).dy;
    expect(returningY, lessThan(endY));
    expect(returningY, greaterThan(startY));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('维生素 D')).dy, closeTo(startY, 1));
  });

  testWidgets(
    'later completions stop above earlier ones and survive reopening',
    (tester) async {
      await setPhoneSize(tester);
      final today = dateOnly(DateTime.now());
      final store = MemoryDailyStore(
        seedItems: [
          singleItem(today),
          eyeDropItem(today),
          singleItem(today).copyWith(title: '喝水'),
        ],
      );
      final items = await store.loadItems();
      await pumpDaily(tester, store);

      Finder card(int index) =>
          find.byKey(ValueKey<String>('group-${items[index].id}'));
      void expectOrder(List<int> order) {
        for (var index = 1; index < order.length; index++) {
          expect(
            tester.getTopLeft(card(order[index - 1])).dy,
            lessThan(tester.getTopLeft(card(order[index])).dy),
          );
        }
      }

      Future<void> toggle(int index) async {
        final button = find.byKey(Key('completion-${items[index].id}'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      Future<void> reopen() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpDaily(tester, store);
      }

      await toggle(0);
      expectOrder([1, 2, 0]);
      await toggle(1);
      expectOrder([2, 1, 0]);
      await toggle(2);
      expectOrder([2, 1, 0]);

      await reopen();
      expectOrder([2, 1, 0]);
      await toggle(0);
      expectOrder([0, 2, 1]);

      await reopen();
      await toggle(0);
      expectOrder([0, 2, 1]);
      await reopen();
      expectOrder([0, 2, 1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dose completion order also determines when the whole group sinks',
    (tester) async {
      await setPhoneSize(tester);
      final today = dateOnly(DateTime.now());
      final store = MemoryDailyStore(
        seedItems: [groupedItem(today), singleItem(today)],
      );
      final items = await store.loadItems();
      final group = items.first;
      await pumpDaily(tester, store);
      await tester.tap(find.text(group.title));
      await tester.pumpAndSettle();

      Finder dose(int index) =>
          find.byKey(Key('dose-${group.times[index].id}'));
      void expectDoseOrder(List<int> order) {
        for (var index = 1; index < order.length; index++) {
          expect(
            tester.getTopLeft(dose(order[index - 1])).dy,
            lessThan(tester.getTopLeft(dose(order[index])).dy),
          );
        }
      }

      Future<void> completeDose(int index) async {
        final button = find.descendant(
          of: dose(index),
          matching: find.byType(CompletionButton),
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await completeDose(0);
      expectDoseOrder([1, 2, 0]);
      final singleButton = find.byKey(Key('completion-${items.last.id}'));
      await tester.ensureVisible(singleButton);
      await tester.pumpAndSettle();
      await tester.tap(singleButton);
      await tester.pumpAndSettle();
      await completeDose(1);
      expectDoseOrder([2, 1, 0]);
      await completeDose(2);
      expectDoseOrder([2, 1, 0]);
      expect(
        tester.getTopLeft(find.byKey(Key('group-${group.id}'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(Key('group-${items.last.id}'))).dy,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

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
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 80));
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

    await tester.tap(find.byKey(const Key('tab-items')));
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
    await tester.tap(find.byKey(const Key('tab-items')));
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

    await tester.tap(find.byKey(const Key('tab-items')));
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

  testWidgets(
    'new item groups essentials and keeps optional fields behind more settings',
    (tester) async {
      await setPhoneSize(tester);
      final store = MemoryDailyStore();
      await pumpDaily(tester, store);
      await tester.tap(find.byKey(const Key('add-item-button')));
      await tester.pumpAndSettle();
      expect(find.text('安排'), findsOneWidget);
      expect(find.text('重复'), findsOneWidget);
      expect(find.text('提醒时间'), findsOneWidget);
      expect(find.text('日期范围'), findsOneWidget);
      expect(find.byKey(const Key('stock-quantity-field')), findsNothing);
      expect(find.byKey(const Key('editor-more-settings')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('icon-vitamin')));
      await tester.enterText(find.byKey(const Key('item-title-field')), '营养补充');
      await tester.tap(find.byKey(const Key('save-item-button')));
      await tester.pumpAndSettle();
      expect((await store.loadItems()).single.iconKey, 'vitamin');
    },
  );

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
      await tester.tap(find.byKey(const Key('editor-more-settings')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('stock-quantity-field')),
        '5',
      );
      await tester.enterText(find.byKey(const Key('dose-quantity-field')), '2');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-sheet-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-repeat-settings')));
      await tester.pumpAndSettle();
      final intervalOption = find.text('隔几天');
      await scrollEditorUntilVisible(tester, intervalOption);
      await tester.tap(intervalOption);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-sheet-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-time-settings')));
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
      await tester.tap(find.byKey(const Key('editor-sheet-done')));
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

    await tester.tap(find.byKey(const Key('editor-time-settings')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const Key('editor-sheet-done')));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(const Key('editor-time-settings')));
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
    await tester.tap(find.byKey(const Key('editor-time-settings')));
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

    expect(
      find.descendant(of: timeRow, matching: find.text('10:30')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'quick time editing keeps completion history and syncs reminders',
    (tester) async {
      await setPhoneSize(tester);
      final today = dateOnly(DateTime.now());
      final store = MemoryDailyStore(
        seedItems: [singleItem(today).copyWith(stockQuantity: 12)],
      );
      final saved = (await store.loadItems()).single;
      await store.setCompletion(
        itemId: saved.id!,
        reminderTimeId: saved.times.single.id!,
        date: today,
        completed: true,
      );
      final scheduler = RecordingReminderScheduler();
      await tester.pumpWidget(
        DailyApp(
          store: store,
          scheduler: scheduler,
          refreshSignal: AppRefreshSignal(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey<String>('quick-time-${saved.id}-${saved.times.single.id}'),
        ),
      );
      await tester.pumpAndSettle();
      await enterTime(tester, '10', '30');
      final updated = (await store.loadItems()).single;
      expect(updated.times.single.minuteOfDay, 630);
      expect(updated.times.single.id, saved.times.single.id);
      expect(updated.remainingQuantity, 11);
      expect(await store.loadCompletionKeys(today, today), {
        completionKey(saved.id!, saved.times.single.id!, today),
      });
      expect(scheduler.lastSynced.single.times.single.minuteOfDay, 630);
      expect(find.byType(ItemEditorPage), findsNothing);

      await tester.tap(find.byKey(const Key('tab-items')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey<String>(
            'management-time-${saved.id}-${saved.times.single.id}',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterTime(tester, '11', '15');
      expect((await store.loadItems()).single.times.single.minuteOfDay, 675);
      expect(scheduler.lastSynced.single.times.single.minuteOfDay, 675);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('quick time editing rejects a duplicate reminder', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final store = MemoryDailyStore(
      seedItems: [groupedItem(dateOnly(DateTime.now()))],
    );
    final item = (await store.loadItems()).single;
    await pumpDaily(tester, store);
    await tester.tap(find.text('感冒药'));
    await tester.pumpAndSettle();
    final dose = find.byKey(ValueKey<String>('dose-${item.times.first.id}'));
    await tester.tap(
      find.descendant(of: dose, matching: find.byType(InkWell)).first,
    );
    await tester.pumpAndSettle();
    await enterTime(tester, '13', '00');
    expect(find.text('这个提醒时间已经存在'), findsOneWidget);
    expect(
      (await store.loadItems()).single.times.map((time) => time.minuteOfDay),
      [480, 780, 1200],
    );
  });

  testWidgets(
    'invalid optional draft is revealed when saving from the main editor',
    (tester) async {
      await setPhoneSize(tester);
      final store = MemoryDailyStore();
      await pumpDaily(tester, store);
      await tester.tap(find.byKey(const Key('add-item-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('item-title-field')), '测试事项');
      await tester.tap(find.byKey(const Key('editor-more-settings')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('dose-quantity-field')), '0');
      await tester.tap(find.byTooltip('关闭设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-item-button')));
      await tester.pumpAndSettle();
      expect(find.text('请输入大于 0 的数字'), findsOneWidget);
      expect(await store.loadItems(), isEmpty);
      await tester.enterText(find.byKey(const Key('dose-quantity-field')), '2');
      await tester.tap(find.byKey(const Key('editor-sheet-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-item-button')));
      await tester.pumpAndSettle();
      expect((await store.loadItems()).single.doseQuantity, 2);
    },
  );

  testWidgets(
    'saving an existing item retains settings hidden by the grouped editor',
    (tester) async {
      await setPhoneSize(tester);
      final today = dateOnly(DateTime.now());
      final seed = groupedItem(today).copyWith(
        stockQuantity: 30,
        doseQuantity: 2,
        stockUnit: '粒',
        productionDate: today.subtract(const Duration(days: 30)),
        expiryDate: today.add(const Duration(days: 100)),
        endDate: today.add(const Duration(days: 10)),
        snoozeMinutes: 60,
        alertMonthBefore: false,
        alertWeekBefore: true,
      );
      final store = MemoryDailyStore(seedItems: [seed]);
      final original = (await store.loadItems()).single;
      await pumpDaily(tester, store);
      await tester.tap(find.byKey(const Key('tab-items')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('感冒药'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stock-quantity-field')), findsNothing);
      await tester.enterText(find.byKey(const Key('item-title-field')), '新的名称');
      await tester.tap(find.byKey(const Key('save-item-button')));
      await tester.pumpAndSettle();
      final updated = (await store.loadItems()).single;
      expect(updated.title, '新的名称');
      expect(updated.stockQuantity, 30);
      expect(updated.doseQuantity, 2);
      expect(updated.stockUnit, '粒');
      expect(updated.productionDate, seed.productionDate);
      expect(updated.expiryDate, seed.expiryDate);
      expect(updated.endDate, seed.endDate);
      expect(updated.snoozeMinutes, 60);
      expect(updated.alertMonthBefore, false);
      expect(updated.alertWeekBefore, true);
      expect(
        updated.times.map((time) => time.id),
        original.times.map((time) => time.id),
      );
    },
  );

  testWidgets('new item save stays above the keyboard on a small phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await pumpDaily(tester, MemoryDailyStore());
    await tester.tap(find.byKey(const Key('add-item-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('item-title-field')), '小屏测试');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('save-item-button'));
    expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(288));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'calendar follows the finger and a short slow drag returns to the same week',
    (tester) async {
      await setPhoneSize(tester);
      await pumpDaily(tester, MemoryDailyStore());
      final selected = find
          .byWidgetPredicate(
            (widget) => widget is CalendarDayCell && widget.selected,
          )
          .first;
      final start = tester.getCenter(selected);
      final today = (tester.widget<CalendarDayCell>(selected)).date;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('calendar-swipe-area'))),
      );
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getCenter(selected).dx, lessThan(start.dx));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();
      expect((tester.widget<CalendarDayCell>(selected)).date, today);
      expect(tester.getCenter(selected).dx, closeTo(start.dx, 1));
      expect(find.byType(CalendarDayCell), findsNWidgets(7));
    },
  );

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
      await tester.tap(find.byTooltip('下一周'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calendar-today-button')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'week width: $width');
      await tester.tap(find.byKey(const Key('calendar-view-toggle')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'month width: $width');
      await tester.tap(find.byTooltip('下个月'));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'next month width: $width',
      );
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
    await tester.tap(find.byKey(const Key('calendar-view-toggle')));
    await tester.pumpAndSettle();

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
