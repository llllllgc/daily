import 'package:daily/app.dart';
import 'package:daily/item_icons.dart';
import 'package:daily/models.dart';
import 'package:daily/services/notification_service.dart';
import 'package:daily/widgets/item_icon.dart';
import 'package:daily/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ReminderItem _item() => ReminderItem(
  title: '维生素 D',
  iconKey: 'vitamin',
  startDate: dateOnly(DateTime.now()),
  repeatKind: RepeatKind.daily,
  times: const [ReminderTime(minuteOfDay: 540, sortOrder: 0)],
);

Future<void> _pump(WidgetTester tester, MemoryDailyStore store) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    DailyApp(
      store: store,
      scheduler: const NoopReminderScheduler(),
      refreshSignal: AppRefreshSignal(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openThemes(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('calendar-settings-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('settings-theme-color')));
  await tester.pumpAndSettle();
}

class _FailingThemeStore extends MemoryDailyStore {
  @override
  Future<void> saveThemeColor(DailyThemeColor color) async =>
      throw StateError('Write failed');
}

void main() {
  testWidgets(
    'more icons rotate and slide inline, retaining the choice when closed',
    (tester) async {
      await _pump(tester, MemoryDailyStore());
      await tester.tap(find.byKey(const Key('add-item-button')));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('editor-icon-settings'));
      final panel = find.byKey(const Key('editor-extra-icons'));
      final settings = find.byKey(const Key('editor-repeat-settings'));
      final rotation = find.descendant(
        of: find.byKey(const Key('editor-icon-toggle-symbol')),
        matching: find.byType(RotationTransition),
      );
      double turns() => tester.widget<RotationTransition>(rotation).turns.value;
      final initialSettingsY = tester.getTopLeft(settings).dy;
      expect(tester.getSize(button), const Size(64, 32));
      final firstIcon = find.byKey(const ValueKey('icon-medication'));
      expect(
        tester.getBottomLeft(button).dy,
        lessThan(tester.getTopLeft(firstIcon).dy),
      );
      expect(tester.getSize(panel).height, 0);
      expect(turns(), 0);
      expect(find.bySemanticsLabel('更多图标'), findsOneWidget);

      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final openingHeight = tester.getSize(panel).height;
      expect(openingHeight, greaterThan(0));
      expect(turns(), allOf(greaterThan(0), lessThan(.125)));
      final slide = find.descendant(
        of: panel,
        matching: find.byType(SlideTransition),
      );
      expect(
        tester.widget<SlideTransition>(slide).position.value.dy,
        lessThan(0),
      );
      await tester.pumpAndSettle();
      final fullHeight = tester.getSize(panel).height;
      expect(fullHeight, greaterThan(openingHeight));
      expect(turns(), .125);
      expect(find.bySemanticsLabel('收起图标'), findsOneWidget);
      expect(
        tester.getTopLeft(settings).dy,
        closeTo(initialSettingsY + fullHeight, .1),
      );
      expect(find.byType(BottomSheet), findsNothing);
      final divider = find.byKey(const Key('editor-extra-icons-divider'));
      expect(divider, findsOneWidget);
      expect(
        tester.getTopLeft(divider).dy,
        greaterThan(tester.getBottomLeft(firstIcon).dy),
      );
      expect(
        tester.getBottomLeft(divider).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('item-icon-medication')))
              .dy,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('item-icon-pill-bottle')));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final closingHeight = tester.getSize(panel).height;
      expect(closingHeight, allOf(greaterThan(0), lessThan(fullHeight)));
      expect(turns(), allOf(greaterThan(0), lessThan(.125)));
      expect(
        tester.widget<SlideTransition>(slide).position.value.dy,
        lessThan(0),
      );
      // Reversing an in-flight collapse must continue from the visible position.
      await tester.tap(button);
      await tester.pump();
      expect(tester.getSize(panel).height, closeTo(closingHeight, .1));
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, fullHeight);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, 0);
      expect(turns(), 0);
      expect(find.byKey(const ValueKey('item-icon-pill-bottle')), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DailyItemIcon && widget.iconKey == 'pill-bottle',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inline icons open and close immediately with reduced motion', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await _pump(tester, MemoryDailyStore());
    await tester.tap(find.byKey(const Key('add-item-button')));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('editor-icon-settings'));
    final panel = find.byKey(const Key('editor-extra-icons'));
    final rotation = find.descendant(
      of: find.byKey(const Key('editor-icon-toggle-symbol')),
      matching: find.byType(RotationTransition),
    );
    await tester.tap(button);
    await tester.pump();
    expect(tester.getSize(panel).height, 81);
    expect(tester.widget<RotationTransition>(rotation).turns.value, .125);
    await tester.tap(button);
    await tester.pump();
    expect(tester.getSize(panel).height, 0);
    expect(tester.widget<RotationTransition>(rotation).turns.value, 0);
    expect(find.byKey(const ValueKey('item-icon-pill-bottle')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'theme changes every screen and is restored after restarting the app',
    (tester) async {
      final store = MemoryDailyStore(seedItems: [_item()]);
      final before = (await store.loadItems()).single;
      await _pump(tester, store);
      await _openThemes(tester);
      for (final color in DailyThemeColor.values) {
        await tester.tap(find.byKey(ValueKey('theme-color-${color.name}')));
        await tester.pumpAndSettle();
        expect(await store.loadThemeColor(), color);
        expect(
          tester.element(find.byType(ThemeColorPage)).palette.pine,
          DailyColors.forTheme(color).pine,
        );
      }
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('灰紫'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      final surface = tester.widget<CompletionFillSurface>(
        find.descendant(
          of: find.byType(TaskGroupView),
          matching: find.byType(CompletionFillSurface),
        ),
      );
      expect(
        surface.baseColor,
        DailyColors.forTheme(DailyThemeColor.lavender).completionFill,
      );
      final after = (await store.loadItems()).single;
      expect(after.id, before.id);
      expect(after.times.single.id, before.times.single.id);
      expect(after.iconKey, before.iconKey);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await _pump(tester, store);
      expect(
        tester.element(find.byType(CalendarPage)).palette.pine,
        DailyColors.forTheme(DailyThemeColor.lavender).pine,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed theme save restores the previous color and reports the failure',
    (tester) async {
      await _pump(tester, _FailingThemeStore());
      await _openThemes(tester);
      await tester.tap(find.byKey(const ValueKey('theme-color-blue')));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(ThemeColorPage)).palette.pine,
        AppPalette.pine,
      );
      expect(find.text('主题颜色没有保存，请重试'), findsOneWidget);
    },
  );

  testWidgets(
    'specific rounded icon saves in its category and can be edited again',
    (tester) async {
      final store = MemoryDailyStore();
      await _pump(tester, store);
      await tester.tap(find.byKey(const Key('add-item-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('item-title-field')), '阅读笔记');
      await tester.tap(find.byKey(const Key('editor-icon-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('icon-study')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('item-icon-notebook-pen')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-icon-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-item-button')));
      await tester.pumpAndSettle();
      final item = (await store.loadItems()).single;
      expect(item.iconKey, 'notebook-pen');
      expect(ItemIcons.categoryFor(item.iconKey).label, '学习');
      expect(courseDetailsLabel(item), '长期 · 每天');
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DailyItemIcon && widget.iconKey == 'notebook-pen',
        ),
        findsWidgets,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ItemEditorPage(store: store, item: item),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DailyItemIcon && widget.iconKey == 'notebook-pen',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('editor-icon-settings')));
      await tester.pumpAndSettle();
      final selected = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey('item-icon-notebook-pen')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(selected.properties.selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all 32 bundled icons paint without loading external resources', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Wrap(
            children: [
              for (final category in ItemIcons.categories)
                for (final icon in category.choices)
                  DailyItemIcon(icon.key, size: 28),
              const DailyItemIcon('unrecognized-legacy-key'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DailyItemIcon), findsNWidgets(33));
    expect(tester.takeException(), isNull);
    for (final category in ItemIcons.categories) {
      for (final choice in category.choices) {
        expect(ItemIcons.categoryFor(choice.key), category);
      }
    }
  });

  testWidgets('theme choices fit a narrow screen with large text', (
    tester,
  ) async {
    final store = MemoryDailyStore();
    await _pump(tester, store);
    await tester.binding.setSurfaceSize(const Size(320, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openThemes(tester);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('theme-color-lavender')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ThemeColorPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-color-lavender')));
    await tester.pumpAndSettle();
    expect(await store.loadThemeColor(), DailyThemeColor.lavender);
    expect(tester.takeException(), isNull);
  });

  test('all theme palettes keep text and primary buttons readable', () {
    double contrast(Color a, Color b) {
      final first = a.computeLuminance(), second = b.computeLuminance();
      return first > second
          ? (first + .05) / (second + .05)
          : (second + .05) / (first + .05);
    }

    for (final color in DailyThemeColor.values) {
      final palette = DailyColors.forTheme(color);
      expect(contrast(palette.ink, palette.canvas), greaterThanOrEqualTo(4.5));
      expect(
        contrast(palette.pine, palette.canvasRaised),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(palette.pineInk, palette.pine),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
