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
      // The editor remains behind the sheet; target the visible sheet controls.
      await tester.tap(find.byKey(const ValueKey('icon-study')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('item-icon-notebook-pen')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-sheet-done')));
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
      expect(find.text('记录 · 更换图标'), findsOneWidget);
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
